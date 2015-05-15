/*
 #* tcpprobe - Observe the TCP flow with kprobes.
 *
 * The idea for this came from Werner Almesberger's umlsim
 * Copyright (C) 2004, Stephen Hemminger <shemminger@osdl.org>
 *
 * Extended by Lyatiss, Inc. <contact@lyatiss.com> to support 
 * per-connection sampling, added additional metrics 
 * and signaling of RST/FIN connections. 
 * Please see the README.md file in the same directory for details.
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#include <linux/kernel.h>
#include <linux/kprobes.h>
#include <linux/socket.h>
#include <linux/tcp.h>
#include <linux/slab.h>
#include <linux/proc_fs.h>
#include <linux/module.h>
#include <linux/ktime.h>
#include <linux/time.h>
#include <linux/jhash.h>
#include <linux/jiffies.h>
#include <linux/list.h>
#include <linux/version.h>
#include <linux/swap.h>
#include <linux/random.h>
#include <linux/vmalloc.h>


#include <net/tcp.h>

MODULE_AUTHOR("Stephen Hemminger <shemminger@linux-foundation.org>");
MODULE_DESCRIPTION("TCP cwnd snooper");
MODULE_LICENSE("GPL");
MODULE_VERSION("1.1.6");

static int port __read_mostly = 0;
MODULE_PARM_DESC(port, "Port to match (0=all)");
module_param(port, int, 0);

static unsigned int bufsize __read_mostly = 4096;
MODULE_PARM_DESC(bufsize, "Log buffer size in packets (4096)");
module_param(bufsize, uint, 0);

static int full __read_mostly;
MODULE_PARM_DESC(full, "Full log (1=every ack packet received,  0=only cwnd changes)");
module_param(full, int, 0);

static int probetime __read_mostly = 500;
MODULE_PARM_DESC(probetime, "Probe time to write flows in milliseconds (500 milliseconds)");
module_param(probetime, int, 0);

static int hashsize __read_mostly = 0;
MODULE_PARM_DESC(hashsize, "hash table size");
module_param(hashsize, int, 0);

static int maxflows __read_mostly = 2000000;
MODULE_PARM_DESC(maxflows, "Maximum number of flows");
module_param(maxflows, int, 0);

static int debug __read_mostly = 0;
MODULE_PARM_DESC(debug, "Enable debug messages (Default 0) debug=1, trace=2");
module_param(debug, int , 0);

static int purgetime __read_mostly = 300;
MODULE_PARM_DESC(purgetime, "Max inactivity in seconds before purging a flow (Default 300 seconds)");

#define PROC_TCPPROBE "tcpprobe"

#define PROC_SYSCTL_TCPPROBE  "lyatiss_cw_tcpprobe"
#define PROC_STAT_TCPPROBE "lyatiss_cw_tcpprobe"

#define UINT32_MAX                 (u32)(~((u32) 0)) /* 0xFFFFFFFF         */
#define UINT16_MAX                  (u16)(~((u16) 0)) /* 0xFFFF         */
#define DEBUG_DISABLE 0
#define DEBUG_ENABLE  1
#define TRACE_ENABLE  2
#define PRINT_DEBUG(fmt, arg...)				\
  do {											\
	if (debug == DEBUG_ENABLE) {				\
	  pr_info(fmt, ##arg);						\
	}											\
  } while(0)

#define PRINT_TRACE(fmt, arg...)							\
  do {														\
	if (debug == DEBUG_ENABLE || debug == TRACE_ENABLE) {	\
	  pr_info(fmt, ##arg);									\
	}														\
  } while(0)

#ifndef pr_err
#define pr_err(fmt, arg...) pr_info(fmt, ##arg)
#endif

	
struct tcp_tuple {
  __be32 saddr;
  __be32 daddr;
  __be16 sport;
  __be16 dport;
};

/* tuple size is rounded to u32s */
#define TCP_TUPLE_SIZE (sizeof(struct tcp_tuple) / 4)

struct tcp_hash_flow {
  struct hlist_node hlist; // hashtable search chain
  struct list_head list; // all flows chain

  /* unique per flow data (hashed, TCP_TUPLE_SIZE) */
  struct tcp_tuple tuple;

  /* Last ACK Timestamp */
  ktime_t tstamp;
  /* Cumulative bytes sent */
  u64 cumulative_bytes;
  /* remember last sequence number */
  u32 last_seq_num;
  u64 first_seq_num;
};

/* statistics */
struct tcpprobe_stat {
  u64 ack_drop_purge;      /* ACK dropped due to purge in progress */
  u64 ack_drop_ring_full;  /* ACK dropped due to slow reader */
  u64 conn_maxflow_limit;  /* Connection skipped due maxflow limit */ 
  u64 conn_memory_limit;   /* Connection skipped because memory was unavailable */
  u64 searched;            /* hash stat - searched */
  u64 found;		 /* hash stat - found */
  u64 notfound;            /* hash stat - not found */
  u64 multiple_readers;    /* Multiple readers for /proc/net/tcpprobe */
  u64 copy_error;          /* Userspace copy error */
  u64 reset_flows; /* Number of FIN/RST received that caused to purge the flow */
};

#define TCPPROBE_STAT_INC(count) (__get_cpu_var(tcpprobe_stat).count++)

struct tcp_log {
  ktime_t tstamp;
  __be32	saddr, daddr;
  __be16	sport, dport;
  u16 length;
  u64 snd_nxt;
  u32 snd_una;
  u32 snd_wnd;
  u32 snd_cwnd;
  u32 ssthresh;
  u32 srtt;
  u32 rttvar;
  u32 lost;
  u32 retrans;
  u32 inflight;
  u32 rto;
  u8 frto_counter;
  u32 rqueue;
  u32 wqueue;
  u64 socket_idf;
};

static struct {
  spinlock_t	lock;
  wait_queue_head_t wait;
  ktime_t		start;
  u32		lastcwnd;

  unsigned long	head, tail;
  struct tcp_log	*log;
} tcp_probe;

static unsigned int tcp_hash_rnd;
static struct hlist_head *tcp_hash __read_mostly; /* hash table memory */
static unsigned int tcp_hash_size __read_mostly = 0; /* buckets */
static struct kmem_cache *tcp_flow_cachep __read_mostly; /* tcp flow memory */
static DEFINE_SPINLOCK(tcp_hash_lock); /* hash table lock */
static LIST_HEAD(tcp_flow_list); /* all flows */
static struct timer_list purge_timer;
static atomic_t flow_count = ATOMIC_INIT(0);
static DEFINE_PER_CPU(struct tcpprobe_stat, tcpprobe_stat);

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,24)
#define INIT_NET(x) x
#else
#define INIT_NET(x) init_net.x
#endif

//Needed because symbol ns_to_timespec is not always exported...
#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,21)
struct timespec ns_to_timespec(const s64 nsec)
{
  struct timespec ts;
  s32 rem;

  if (!nsec)
	return (struct timespec) {0, 0};

  ts.tv_sec = div_s64_rem(nsec, NSEC_PER_SEC, &rem);
  if (unlikely(rem < 0)) {
	ts.tv_sec--;
	rem += NSEC_PER_SEC;
  }
  ts.tv_nsec = rem;

  return ts;
}
#endif


static inline int tcp_probe_used(void)
{
  return (tcp_probe.head - tcp_probe.tail) & (bufsize - 1);
}

static inline int tcp_probe_avail(void)
{
  return bufsize - tcp_probe_used() - 1;
}

static inline int tcp_tuple_equal(const struct tcp_tuple *t1,
								  const struct tcp_tuple *t2)
{
  return (!memcmp(t1, t2, sizeof(struct tcp_tuple)));
}

static inline u_int32_t hash_tcp_flow(const struct tcp_tuple *tuple)
{
  /* tuple is rounded to u32s */
  return jhash2((u32 *)tuple, TCP_TUPLE_SIZE, tcp_hash_rnd) % tcp_hash_size;
}

static struct tcp_hash_flow* 
tcp_flow_find(const struct tcp_tuple *tuple, unsigned int hash)
{
  struct tcp_hash_flow *flow;
#if LINUX_VERSION_CODE < KERNEL_VERSION(3,9,0)
  struct hlist_node *pos;
  hlist_for_each_entry(flow, pos, &tcp_hash[hash], hlist) {
#else
	//Second argument was removed 
	hlist_for_each_entry(flow, &tcp_hash[hash], hlist) {
#endif
	  if (tcp_tuple_equal(tuple, &flow->tuple)) {
		TCPPROBE_STAT_INC(found);
		return flow;
	  }
	  TCPPROBE_STAT_INC(searched);
	}
	TCPPROBE_STAT_INC(notfound);
	return NULL;
  }

  static struct hlist_head * alloc_hashtable(int size)
  {
	struct hlist_head *hash;
	hash = vmalloc(sizeof(struct hlist_head) * size);
	if (hash) {
	  int i;
	  for (i = 0; i < size; i++) {
		INIT_HLIST_HEAD(&hash[i]);
	  }
	} else {
	  pr_err("Unable to vmalloc hash table size = %d\n", size);
	}
	return hash;
  }

  static struct tcp_hash_flow*
	tcp_hash_flow_alloc(struct tcp_tuple *tuple)
  {
	struct tcp_hash_flow *flow;
	flow = kmem_cache_alloc(tcp_flow_cachep, GFP_ATOMIC);
	if (!flow) {
	  pr_err("Cannot allocate tcp_hash_flow.\n");
	  TCPPROBE_STAT_INC(conn_memory_limit);
	  return NULL;
	}
	memset(flow, 0, sizeof(struct tcp_hash_flow));
	flow->tuple = *tuple;
	atomic_inc(&flow_count);
	return flow;
  }

  static void tcp_hash_flow_free(struct tcp_hash_flow *flow)
  {
	atomic_dec(&flow_count);
	kmem_cache_free(tcp_flow_cachep, flow);
  }

  static struct tcp_hash_flow*
	init_tcp_hash_flow(struct tcp_tuple *tuple,
					   ktime_t tstamp, unsigned int hash)
  {
	struct tcp_hash_flow *flow;
	flow = tcp_hash_flow_alloc(tuple);
	if (!flow) {
	  return NULL;
	}
	flow->tstamp = tstamp;
	hlist_add_head(&flow->hlist, &tcp_hash[hash]);
	INIT_LIST_HEAD(&flow->list);
	list_add(&flow->list, &tcp_flow_list);

	return flow;
  }

  static void purge_timer_run(unsigned long dummy)
  {
	struct tcp_hash_flow *flow;
	struct tcp_hash_flow *temp;

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,21)
	struct timespec ts; 
	ktime_t tstamp;
	getnstimeofday(&ts);
	tstamp = timespec_to_ktime(ts);
#else
	ktime_t tstamp = ktime_get();
#endif

	PRINT_DEBUG("Running purge timer.\n");
	spin_lock(&tcp_hash_lock);
	list_for_each_entry_safe(flow, temp, &tcp_flow_list, list) {

	  struct timespec tv = ktime_to_timespec(ktime_sub(tstamp, flow->tstamp));

	  if (tv.tv_sec >= purgetime) {
		PRINT_DEBUG("Purging flow src: %pI4 dst: %pI4"
					" src_port: %u dst_port: %u\n",
					&flow->tuple.saddr, &flow->tuple.daddr,
					ntohs(flow->tuple.sport), ntohs(flow->tuple.dport));
		// Remove from Hashtable
		hlist_del(&flow->hlist);
		// Remove from Global List
		list_del(&flow->list);
		// Free memory
		tcp_hash_flow_free(flow);
	  }
	}
	spin_unlock(&tcp_hash_lock);
	mod_timer(&purge_timer, jiffies + (HZ * purgetime));			
  }

  static void purge_all_flows(void)
  {
	//Method to make sure to release all memory before calling kmem_cache_destroy
	struct tcp_hash_flow *flow;
	struct tcp_hash_flow *temp;

	PRINT_DEBUG("Purging all flows.\n");
	spin_lock(&tcp_hash_lock);
	list_for_each_entry_safe(flow, temp, &tcp_flow_list, list) {
	  // Remove from Hashtable
	  hlist_del(&flow->hlist);
	  // Remove from Global List
	  list_del(&flow->list);
	  // Free memory
	  tcp_hash_flow_free(flow);
  
	}
	spin_unlock(&tcp_hash_lock);

  }



  /*
   * Utility function to write the flow record
   * Assumes that the spin_lock on the tcp_probe has been taken
   * before calling it
   */
  static int write_flow(struct tcp_tuple *tuple, const struct tcp_sock *tp, ktime_t tstamp, 
						u64 cumulative_bytes, u16 length, u32 ssthresh,
						struct sock *sk, u64 first_seq_seen){
    
	/* If log fills, just silently drop */
	if (tcp_probe_avail() > 1) {
	  struct tcp_log *p = tcp_probe.log + tcp_probe.head;
        
	  p->tstamp = tstamp; 
	  p->saddr = tuple->saddr;
	  p->sport = tuple->sport;
	  p->daddr = tuple->daddr;
	  p->dport = tuple->dport;
	  p->length = length;
	  /* update the cumulative bytes */
	  p->snd_nxt = cumulative_bytes;
	  p->snd_una = tp->snd_una;
	  p->snd_cwnd = tp->snd_cwnd;
	  p->snd_wnd = tp->snd_wnd;
	  p->ssthresh = ssthresh;

#if LINUX_VERSION_CODE < KERNEL_VERSION(3,15,0)
	  p->srtt = jiffies_to_usecs(tp->srtt) >> 3;
	  p->rttvar = jiffies_to_usecs(tp->rttvar) >>3;
#else
	  /* element was renamed */ 
	  p->srtt = tp->srtt_us >> 3;
	  p->rttvar = tp->rttvar_us >>3;
#endif

	  p->lost = tp->lost_out;
	  p->retrans = tp->total_retrans;
	  p->inflight = tp->packets_out;
	  p->rto = p->srtt + (4 * p->rttvar);

#if LINUX_VERSION_CODE < KERNEL_VERSION(3,10,0)
	  p->frto_counter = tp->frto_counter;
#else
	  p->frto_counter = tp->frto;	
#endif        

	  /* same method as tcp_diag to retrieve the queue sizes */
	  if (sk->sk_state == TCP_LISTEN) {
		p->rqueue = sk->sk_ack_backlog;
		p->wqueue = sk->sk_max_ack_backlog;
	  } else {
		p->rqueue = max_t(int, tp->rcv_nxt - tp->copied_seq, 0);
		p->wqueue = tp->write_seq - tp->snd_una;
	  }

	  p->socket_idf = first_seq_seen;

	  tcp_probe.head = (tcp_probe.head + 1) & (bufsize - 1);
	} else {
	  TCPPROBE_STAT_INC(ack_drop_ring_full);
	}
	tcp_probe.lastcwnd = tp->snd_cwnd;
	return 0;
  }



  /*
   * Hook inserted to be called before each time a socket is close
   * This allow us to purge/flush the corresponding infos
   * Note: arguments must match tcp_done()!
   * 
   */
  static void jtcp_done(struct sock *sk)
  {
  
	const struct tcp_sock *tp = tcp_sk(sk);
	const struct inet_sock *inet = inet_sk(sk);
	struct tcp_tuple tuple;
	struct tcp_hash_flow *tcp_flow;
	unsigned int hash;
	u64 cumulative_bytes = 0;


#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,21)
	struct timespec ts; 
	ktime_t tstamp;
	getnstimeofday(&ts);
	tstamp = timespec_to_ktime(ts);
#else
	ktime_t tstamp = ktime_get();
#endif


    
#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,32)
	tuple.saddr = inet->inet_saddr;
	tuple.daddr = inet->inet_daddr;
	tuple.sport = inet->inet_sport;
	tuple.dport = inet->inet_dport;
#else
	tuple.saddr = inet->saddr;
	tuple.daddr = inet->daddr;
	tuple.sport = inet->sport;
	tuple.dport = inet->dport;
#endif
	
	PRINT_DEBUG("Reset flow src: %pI4 dst: %pI4"
				" src_port: %u dst_port: %u\n",
				&tuple.saddr, &tuple.daddr,
				ntohs(tuple.sport), ntohs(tuple.dport));
    
	hash = hash_tcp_flow(&tuple);
	/* Making sure that we are the only one touching this flow */
	spin_lock(&tcp_hash_lock);
    
	tcp_flow = tcp_flow_find(&tuple, hash);
	if (!tcp_flow) {
	  /*We just saw the FIN for this one so we can probably forget it */
	  PRINT_DEBUG("FIN for flow src: %pI4 dst: %pI4"
				  " src_port: %u dst_port: %u but no corresponding hash\n",
				  &tuple.saddr, &tuple.daddr,
				  ntohs(tuple.sport), ntohs(tuple.dport));
	  spin_unlock(&tcp_hash_lock);
	  goto skip;
	} else {
	  /*Retrieve the last value of the cumulative_bytes */
	  if (tp->snd_nxt > tcp_flow->last_seq_num) {
		tcp_flow->cumulative_bytes += (tp->snd_nxt - tcp_flow->last_seq_num);
	  } else if (tp->snd_nxt != tcp_flow->last_seq_num) { /* Retransmits */
		/* sequence number rollover. For 10 Gbits/sec flow this will
		   happen every 4 seconds */
		tcp_flow->cumulative_bytes += ((UINT32_MAX - tcp_flow->last_seq_num) + tp->snd_nxt);
	  }
	  tcp_flow->last_seq_num = tp->snd_nxt;
	  cumulative_bytes = tcp_flow->cumulative_bytes; 
        
	}

	//Get the other lock and write
	spin_lock(&tcp_probe.lock);
	TCPPROBE_STAT_INC(reset_flows);
	write_flow(&tuple, tp, tstamp, 
			   cumulative_bytes, UINT16_MAX, tcp_current_ssthresh(sk), sk, tcp_flow->first_seq_num);
    
	spin_unlock(&tcp_probe.lock);
    
	/* Release the flow tuple*/
	// Remove from Hashtable
	hlist_del(&tcp_flow->hlist);
	// Remove from Global List
	list_del(&tcp_flow->list);
	// Free memory
	tcp_hash_flow_free(tcp_flow);
  
	spin_unlock(&tcp_hash_lock);
	wake_up(&tcp_probe.wait);

  skip:
	jprobe_return();
	return;
  }

  /*
   * Hook inserted to be called before each receive packet.
   * Note: arguments must match tcp_rcv_established()!
   */
  static int jtcp_rcv_established(struct sock *sk, struct sk_buff *skb,
								  struct tcphdr *th, unsigned len)
  {
  
	const struct tcp_sock *tp = tcp_sk(sk);
	const struct inet_sock *inet = inet_sk(sk);
	int should_write_flow = 0;
	u16 length = skb->len;
	struct tcp_tuple tuple;
	struct tcp_hash_flow *tcp_flow;
	unsigned int hash;
	u64 cumulative_bytes = 0;

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,21)
	struct timespec ts; 
	ktime_t tstamp;
	getnstimeofday(&ts);
	tstamp = timespec_to_ktime(ts);
#else
	ktime_t tstamp = ktime_get();
#endif

#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,32)
	tuple.saddr = inet->inet_saddr;
	tuple.daddr = inet->inet_daddr;
	tuple.sport = inet->inet_sport;
	tuple.dport = inet->inet_dport;
#else
	tuple.saddr = inet->saddr;
	tuple.daddr = inet->daddr;
	tuple.sport = inet->sport;
	tuple.dport = inet->dport;
#endif

	hash = hash_tcp_flow(&tuple);
	if (spin_trylock(&tcp_hash_lock) == 0) {
	  /* Purge is ongoing.. skip this ACK  */
	  TCPPROBE_STAT_INC(ack_drop_purge);
	  goto skip;
	}
	tcp_flow = tcp_flow_find(&tuple, hash);
        
	if (!tcp_flow) {
	  if (maxflows > 0 && atomic_read(&flow_count) >= maxflows) {
		/* This is DOC attack prevention */
		TCPPROBE_STAT_INC(conn_maxflow_limit);
		PRINT_DEBUG("Flow count = %u execeed max flow = %u\n", 
					atomic_read(&flow_count), maxflows);
	  } else {
		/* create an entry in hashtable */
		PRINT_DEBUG("Init new flow src: %pI4 dst: %pI4"
					" src_port: %u dst_port: %u\n",
					&tuple.saddr, &tuple.daddr,
					ntohs(tuple.sport), ntohs(tuple.dport));
		tcp_flow = init_tcp_hash_flow(&tuple, tstamp, hash);
		tcp_flow->first_seq_num = tp->snd_nxt; 
		should_write_flow = 1;
	  }
	} else {
	  /* if the difference between timestamps is >= probetime then write the flow to ring */
	  struct timespec tv = ktime_to_timespec(ktime_sub(tstamp, tcp_flow->tstamp));	
	  u_int64_t milliseconds = (tv.tv_sec * MSEC_PER_SEC) + (tv.tv_nsec/NSEC_PER_MSEC);
	  if (milliseconds >= probetime) { 
		tcp_flow->tstamp = tstamp;
		should_write_flow = 1;
	  }
	}
	if (should_write_flow) {
	  if (tp->snd_nxt > tcp_flow->last_seq_num) {
		tcp_flow->cumulative_bytes += (tp->snd_nxt - tcp_flow->last_seq_num);
	  } else if (tp->snd_nxt != tcp_flow->last_seq_num) { /* Retransmits */
		/* sequence number rollover. For 10 Gbits/sec flow this will
		   happen every 4 seconds */
		tcp_flow->cumulative_bytes += ((UINT32_MAX - tcp_flow->last_seq_num) + tp->snd_nxt);
	  }
	  tcp_flow->last_seq_num = tp->snd_nxt;
	  cumulative_bytes = tcp_flow->cumulative_bytes;
	}
	
	/* Only update if port matches */
	if ((port == 0 || ntohs(tuple.dport) == port ||
		 ntohs(tuple.sport) == port) &&
		(full || tp->snd_cwnd != tcp_probe.lastcwnd) &&
		should_write_flow) {
        
	  spin_lock(&tcp_probe.lock);
	  write_flow(&tuple, tp, tstamp, 
				 cumulative_bytes, length, tcp_current_ssthresh(sk), sk, tcp_flow->first_seq_num);
        
	  spin_unlock(&tcp_probe.lock);
	  wake_up(&tcp_probe.wait);
		
	}

	spin_unlock(&tcp_hash_lock);

  skip:
	jprobe_return();
	return 0;
  }

  static struct jprobe tcp_jprobe = {
	.kp = {
	  .symbol_name	= "tcp_rcv_established",
	},
	.entry	= (kprobe_opcode_t *) jtcp_rcv_established,
  };


  static struct jprobe tcp_jprobe_done = {
	.kp = {
	  .symbol_name = "tcp_done",
	},
	.entry = (kprobe_opcode_t *) jtcp_done,
  };


  static int tcpprobe_open(struct inode * inode, struct file * file)
  {
#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,23)
	struct timespec ts; 
#endif

	/* Reset (empty) log */
	spin_lock_bh(&tcp_probe.lock);
	tcp_probe.head = tcp_probe.tail = 0;
#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,21)
	getnstimeofday(&ts);
    tcp_probe.start = timespec_to_ktime(ts);
#else
	tcp_probe.start = ktime_get();
#endif
	spin_unlock_bh(&tcp_probe.lock);

	return 0;
  }

  static int tcpprobe_sprint(char *tbuf, int n)
  {
	const struct tcp_log *p
	  = tcp_probe.log + tcp_probe.tail;
	struct timespec tv
	  = ktime_to_timespec(ktime_sub(p->tstamp, tcp_probe.start));

	return scnprintf(tbuf, n,
					 "%lu.%09lu %pI4:%u %pI4:%u %d %#llx %#x %u %u %u %u %u %u %u %u %u %u %u %u %#llx\n",
					 (unsigned long) tv.tv_sec,
					 (unsigned long) tv.tv_nsec,
					 &p->saddr, ntohs(p->sport),
					 &p->daddr, ntohs(p->dport),
					 p->length, p->snd_nxt, p->snd_una,
					 p->snd_cwnd, p->ssthresh, p->snd_wnd, p->srtt,
					 p->rttvar, p->rto, p->lost, p->retrans, p->inflight, p->frto_counter,
					 p->rqueue, p->wqueue, p->socket_idf);
  }

  static ssize_t tcpprobe_read(struct file *file, char __user *buf,
							   size_t len, loff_t *ppos)
  {
	int error = 0;
	size_t cnt = 0;

	if (!buf)
	  return -EINVAL;
	PRINT_TRACE("Page size is %lu. Buffer len is %zu.\n", PAGE_SIZE, len);

	while (cnt < len) {
	  char tbuf[164];
	  int width;

	  /* Wait for data in buffer */
	  error = wait_event_interruptible(tcp_probe.wait,
									   tcp_probe_used() > 0);
	  if (error)
		break;
	
	  spin_lock_bh(&tcp_probe.lock);
	  if (tcp_probe.head == tcp_probe.tail) {
		/* multiple readers race? */
		TCPPROBE_STAT_INC(multiple_readers);
		spin_unlock_bh(&tcp_probe.lock);
		continue;
	  }

	  width = tcpprobe_sprint(tbuf, sizeof(tbuf));
	
	  if (cnt + width < len) {
		tcp_probe.tail = (tcp_probe.tail + 1) & (bufsize - 1);
	  }
			
	  spin_unlock_bh(&tcp_probe.lock);
		
	  /* if record greater than space available
		 return partial buffer (so far) */
	  if (cnt + width >= len) {
		break;
	  }
	  if (copy_to_user(buf + cnt, tbuf, width)) {
		TCPPROBE_STAT_INC(copy_error);
		return -EFAULT;
	  }
	  cnt += width;
	}

	return cnt == 0 ? error : cnt;
  }

  /* procfs statistics /proc/net/stat/tcpprobe */
  static int tcpprobe_seq_show(struct seq_file *seq, void *v)
  {
	unsigned int nr_flows = atomic_read(&flow_count);
	struct tcpprobe_stat stat;
	int cpu;

	memset(&stat, 0, sizeof(struct tcpprobe_stat));
	
	for_each_present_cpu(cpu) {
	  struct tcpprobe_stat *cpu_stat = &per_cpu(tcpprobe_stat, cpu);
		
	  stat.ack_drop_purge += cpu_stat->ack_drop_purge;
	  stat.ack_drop_ring_full += cpu_stat->ack_drop_ring_full;
	  stat.conn_maxflow_limit += cpu_stat->conn_maxflow_limit;
	  stat.conn_memory_limit += cpu_stat->conn_memory_limit;
	  stat.searched += cpu_stat->searched;
	  stat.found += cpu_stat->found;
	  stat.notfound += cpu_stat->notfound;
	  stat.multiple_readers += cpu_stat->multiple_readers;
	  stat.copy_error += cpu_stat->copy_error;
	  stat.reset_flows += cpu_stat->reset_flows;
	}
	seq_printf(seq, "Flows: active %u mem %uK\n", nr_flows,
			   (unsigned int)((nr_flows * sizeof(struct tcp_hash_flow)) >> 10));
	seq_printf(seq, "Hash: size %u mem %uK\n",
			   hashsize, (unsigned int)((hashsize * sizeof(struct hlist_head)) >> 10));
	seq_printf(seq, "cpu# hash_stat: <search_flows found new reset>, ack_drop: <purge_in_progress ring_full>, conn_drop: <maxflow_reached memory_alloc_failed>, err: <multiple_reader copy_failed>\n");
	seq_printf(seq, "Total: hash_stat: %6llu %6llu %6llu %6llu, ack_drop: %6llu %6llu, conn_drop: %6llu %6llu, err: %6llu %6llu\n",
			   stat.searched, stat.found, stat.notfound, stat.reset_flows,
			   stat.ack_drop_purge, stat.ack_drop_ring_full,
			   stat.conn_maxflow_limit, stat.conn_memory_limit,
			   stat.multiple_readers, stat.copy_error);
	if (num_present_cpus() > 1) {
	  for_each_present_cpu(cpu) {
		struct tcpprobe_stat *cpu_stat = &per_cpu(tcpprobe_stat, cpu);
		seq_printf(seq, "cpu%u: hash_stat: %6llu %6llu %6llu %6llu, ack_drop: %6llu %6llu, conn_drop: %6llu %6llu, err: %6llu %6llu\n",
				   cpu,
				   cpu_stat->searched, cpu_stat->found, stat.notfound, stat.reset_flows,
				   cpu_stat->ack_drop_purge, cpu_stat->ack_drop_ring_full,
				   cpu_stat->conn_maxflow_limit, cpu_stat->conn_memory_limit,
				   cpu_stat->multiple_readers, cpu_stat->copy_error);
	  }
	}
	return 0;
  }

  static int tcpprobe_seq_open(struct inode *inode, struct file *file)
  {
	return single_open(file, tcpprobe_seq_show, NULL);
  }

  static struct ctl_table_header *tcpprobe_sysctl_header;
#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,20)
#define _CTL_NAME(x) .ctl_name = x,
#else
#define _CTL_NAME(x)
#endif

  static struct ctl_table tcpprobe_sysctl_table[] = {
	{
	  _CTL_NAME(1)
	  .procname = "debug",
	  .mode = 0644,
	  .data = &debug,
	  .maxlen = sizeof(int),
	  .proc_handler = &proc_dointvec,
	},
	{
	  _CTL_NAME(2)
	  .procname = "probetime",
	  .mode = 0644,
	  .data = &probetime,
	  .maxlen = sizeof(int),
	  .proc_handler = &proc_dointvec,
	},
	{
	  _CTL_NAME(3)
	  .procname = "maxflows",
	  .mode = 0644,
	  .data = &maxflows,
	  .maxlen = sizeof(int),
	  .proc_handler = &proc_dointvec,
	},
	{
	  _CTL_NAME(4)
	  .procname = "full",
	  .mode = 0644,
	  .data = &full,
	  .maxlen = sizeof(int),
	  .proc_handler = &proc_dointvec,
	},
	{
	  _CTL_NAME(5)
	  .procname = "port",
	  .mode = 0644,
	  .data = &port,
	  .maxlen = sizeof(int),
	  .proc_handler = &proc_dointvec,
	},
	{
	  _CTL_NAME(6)
	  .procname = "hashsize",
	  .mode = 0444, /* readonly */
	  .data = &hashsize,
	  .maxlen = sizeof(int),
	  .proc_handler = &proc_dointvec,
	},
	{
	  _CTL_NAME(7)
	  .procname = "bufsize",
	  .mode = 0444, /* readonly */
	  .data = &bufsize,
	  .maxlen = sizeof(int),
	  .proc_handler = &proc_dointvec,
	},
	{ 
	  _CTL_NAME(8)
	  .procname = "purge_time",
	  .mode = 0644, 
	  .data = &purgetime,
	  .maxlen = sizeof(int),
	  .proc_handler = &proc_dointvec, 
	},
	{}
  };

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,25)
  static struct ctl_table tcpprobe_sysctl_root[] = {
	{
	  _CTL_NAME(33)
	  .procname = PROC_SYSCTL_TCPPROBE,
	  .mode = 0555,
	  .child = tcpprobe_sysctl_table,
	},
	{ }
  };

  static struct ctl_table tcpprobe_net_table[] = {
	{
	  .ctl_name = CTL_NET,
	  .procname = "net",
	  .mode = 0555,
	  .child = tcpprobe_sysctl_root,
	},
	{ }
  };
#else /* >= 2.6.25 */
  static struct ctl_path tcpprobe_sysctl_path[] = {
	{
	  .procname = "net",
#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,33)
	  .ctl_name = CTL_NET
#endif
	},
	{ .procname = PROC_SYSCTL_TCPPROBE },
	{ }
  };
#endif /* 2.6.25 */

  static const struct file_operations tcpprobe_fops = {
	.owner	 = THIS_MODULE,
	.open	 = tcpprobe_open,
	.read    = tcpprobe_read,
  };

  static const struct file_operations tcpprobe_stat_fops = {
	.owner = THIS_MODULE,
	.open  = tcpprobe_seq_open,
	.read  = seq_read,
	.llseek = seq_lseek,
	.release = single_release,
  };

  static __init int tcpprobe_init(void)
  {
	int ret = -ENOMEM;
	struct proc_dir_entry *proc_stat;

	init_waitqueue_head(&tcp_probe.wait);
	spin_lock_init(&tcp_probe.lock);

	if (bufsize == 0) {
	  pr_err("Bufsize is 0\n");
	  return -EINVAL;
	}
	
	/* Hashtable initialization */
	get_random_bytes(&tcp_hash_rnd, 4);
	
	/* determine hash size (idea from nf_conntrack_core.c) */
	if (!hashsize) {
	  hashsize = (((totalram_pages << PAGE_SHIFT) / 16384)
				  / sizeof(struct hlist_head));
	  if (totalram_pages > (1024 * 1024 * 1024 / PAGE_SIZE)) {
		hashsize = 16384;
	  }
	}
	if (hashsize < 32) {
	  hashsize = 32;
	}
	pr_info("Hashtable initialized with %u buckets\n", hashsize);

	tcp_hash_size = hashsize;
	tcp_hash = alloc_hashtable(tcp_hash_size);
	if (!tcp_hash) {
	  pr_err("Unable to create tcp hashtable\n");
	  goto err;
	}
	tcp_flow_cachep = kmem_cache_create("tcp_flow",
										sizeof(struct tcp_hash_flow), 0, 0, NULL
#if LINUX_VERSION_CODE < KERNEL_VERSION(2, 6, 23)
										, NULL
#endif
										);
	if (!tcp_flow_cachep) {
	  pr_err("Unable to create tcp_flow slab cache\n");
	  goto err_free_hash;
	}	
	setup_timer(&purge_timer, purge_timer_run, 0);
	mod_timer(&purge_timer, jiffies + (HZ * purgetime));


#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,25)
	tcpprobe_sysctl_header = register_sysctl_table(tcpprobe_net_table
#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,21)
												   ,0 /* insert_at_head */
#endif
												   );
#else /* 2.6.25 */
	tcpprobe_sysctl_header = register_sysctl_paths(tcpprobe_sysctl_path, tcpprobe_sysctl_table);
#endif
	if (!tcpprobe_sysctl_header) {
	  pr_err("tcpprobe: can't register to sysctl\n");
	  goto err0;
	} else {
	  pr_info("tcpprobe: registered: sysclt net.%s\n", PROC_SYSCTL_TCPPROBE);
	}	
	
	//create_proc_entry has been deprecated by proc_create since 3.10
	proc_stat = proc_create(PROC_STAT_TCPPROBE, S_IRUGO, INIT_NET(proc_net_stat), &tcpprobe_stat_fops); 

	if (!proc_stat) {
	  pr_err("Unable to create /proc/net/stat/%s entry \n", PROC_STAT_TCPPROBE);
	  goto err_free_sysctl;
	}

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,30)
	proc_stat->owner = THIS_MODULE;
#endif
	pr_info("tcpprobe: registered: /proc/net/stat/%s\n", PROC_STAT_TCPPROBE);


	bufsize = roundup_pow_of_two(bufsize);
	tcp_probe.log = kcalloc(bufsize, sizeof(struct tcp_log), GFP_KERNEL);
	if (!tcp_probe.log) {
	  pr_err("Unable to allocate tcp_log memory.\n");
	  goto err_free_proc_stat;
	}

	//proc_net_fops_create has been deprecated by proc_create since 3.10
	if (!proc_create(PROC_TCPPROBE, S_IRUSR, INIT_NET(proc_net), &tcpprobe_fops)) {
	  pr_err("Unable to create /proc/net/tcpprobe\n");
	  goto err_free_proc_stat;
	}

	ret = register_jprobe(&tcp_jprobe);
	if (ret) {
	  pr_err("Unable to register jprobe.\n");
	  goto err1;
	}
    

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,22)
	pr_info("Not registering jprobe on tcp_done as it is an inline method in this kernel version.\n");
#else
    ret = register_jprobe(&tcp_jprobe_done);
    if (ret) {
	  pr_err("Unable to register jprobe on tcp_done.\n");
	  goto err_tcpdone;
	}
#endif 

	pr_info("TCP probe registered (port=%d) bufsize=%u probetime=%d maxflows=%u\n", 
			port, bufsize, probetime, maxflows);
	PRINT_DEBUG("Sizes tcp_hash_flow: %zu, hlist_head = %zu tcp_hash = %zu\n", 
				sizeof(struct tcp_hash_flow), sizeof(struct hlist_head), sizeof(tcp_hash));
	PRINT_DEBUG("Sizes hlist_node = %zu list_head = %zu, ktime_t = %zu tcp_tuple = %zu\n", 
				sizeof(struct hlist_node), sizeof(struct list_head), sizeof(ktime_t), sizeof(struct tcp_tuple));
	PRINT_DEBUG("Sizes tcp_log = %zu\n", sizeof (struct tcp_log));
	return 0;
  err_tcpdone:
	unregister_jprobe(&tcp_jprobe);
  err1:
	remove_proc_entry(PROC_TCPPROBE, INIT_NET(proc_net));
  err_free_proc_stat:
	remove_proc_entry(PROC_STAT_TCPPROBE, INIT_NET(proc_net_stat));
  err_free_sysctl:
	unregister_sysctl_table(tcpprobe_sysctl_header);
  err0:
	del_timer_sync(&purge_timer);
	kfree(tcp_probe.log);
	kmem_cache_destroy(tcp_flow_cachep);
  err_free_hash:
	vfree(tcp_hash);
  err:
	return ret;
  }
  module_init(tcpprobe_init);

  static __exit void tcpprobe_exit(void)
  {
	remove_proc_entry(PROC_TCPPROBE, INIT_NET(proc_net));
	remove_proc_entry(PROC_STAT_TCPPROBE, INIT_NET(proc_net_stat));
	unregister_sysctl_table(tcpprobe_sysctl_header);
	unregister_jprobe(&tcp_jprobe);
	
#if LINUX_VERSION_CODE >=  KERNEL_VERSION(2,6,22)	
	unregister_jprobe(&tcp_jprobe_done);
#endif	

	kfree(tcp_probe.log);
	del_timer_sync(&purge_timer);
	/* tcp flow table memory */
	purge_all_flows();
	kmem_cache_destroy(tcp_flow_cachep);
	vfree(tcp_hash);
	pr_info("TCP probe unregistered.\n");
  }
  module_exit(tcpprobe_exit);
