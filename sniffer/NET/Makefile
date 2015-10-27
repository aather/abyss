
#This won't work if the CONFIG_NET_TCPPROBE isn't already configured 
#for the kernel 
#obj-$(CONFIG_NET_TCPPROBE) += tcp_probe.o

obj-m += tcp_probe_plus.o

all: modules

modules:
		make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

modules_install:
		make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules_install

clean:
		make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
