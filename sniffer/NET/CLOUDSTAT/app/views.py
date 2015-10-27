import os
from threading import Thread
from Queue import Queue
from threading import *
import sys
import io, json
import traceback
import json
from collections import defaultdict
import re
import threading
import decimal
from threading import Thread, current_thread
from django.http import HttpResponse
lstData=[]
lstConn=[]
qConn = Queue(maxsize=0)
numThreadOfProcessing = 1
isactive=0
threads=[]
import time
from time import gmtime, strftime
def startCapturing(request):
    global qConn
    global isactive
    #isactive=1
    if isactive!=1:
        return HttpResponse('No Active Thread')
        
    
    #print 'inside start capturing'
    #while  qConn.empty():
    #        const=1 
    if not qConn.empty():
        data= qConn.get()
    else:
        return HttpResponse('No data in queue')
        
    #print data
        tempTime=data[0]
    qConn.task_done()
    lstOfData=[]
    #lstOfData.append(data)
    d = defaultdict(list)
    if not qConn.empty():
        Newdata=qConn.get()
    else:
        return HttpResponse('No data in queue')
    #print 'New data ' ,Newdata
    while(Newdata[0]==data[0]):
        #print 'inside while'
        match = re.search(r'(:)(\d+)', Newdata[3])
        if match:
                d[match.group(2)].append(int(Newdata[5],16))#CumulativeBytes
                d[match.group(2)].append(int(Newdata[7]))#SSTHRESH
                d[match.group(2)].append(int(Newdata[8]))#CWND
                d[match.group(2)].append(int(Newdata[9]))#RWND
                d[match.group(2)].append(int(Newdata[10]))#SRTT
                d[match.group(2)].append(int(Newdata[12]))#RTO
		d[match.group(2)].append(Newdata[2])#Source
          	d[match.group(2)].append(Newdata[3])#Destination
          	d[match.group(2)].append(int(Newdata[4]))#Length
          	d[match.group(2)].append(int(Newdata[11]))#RTTVAR
          	d[match.group(2)].append(int(Newdata[13]))#LOST
          	d[match.group(2)].append(int(Newdata[14]))#RETRANSMIT
          	d[match.group(2)].append(int(Newdata[15]))#INFLIGHT
          	d[match.group(2)].append(int(Newdata[16]))#FRTO
          	d[match.group(2)].append(int(Newdata[17]))#RQUEUE
          	d[match.group(2)].append(int(Newdata[18]))#WQUEUE
          	d[match.group(2)].append(Newdata[19])#FIRSTSEQ
          	d[match.group(2)].append(Newdata[19])#FIRSTSEQ
          	d[match.group(2)].append(Newdata[6])#LASTUNSEQ
        else:
            return HttpResponse('No data present')
        Newdata=qConn.get()
        # while ended here
    #for key in d:
    #            val=((float(d[key][3])*1460)/(float(d[key][4])/1000))/(1024*1024)
    #            decimalVal = float(round(decimal.Decimal(val),2))
    #            d[key].append(decimalVal)
    #return HttpResponse(Newdata[0] + json.dumps(d))
    #if  len(d.keys())<=100:
    strjson='['
    for k in d:
        strjson=strjson  + ' { ' + """ "PortNumber" : """ + """ "%s" """ % (k) +","
        dk=d[k]
        for x in range(len(dk)):
                if x==0:
                    strjson=strjson  + """ "CumulativeBytes" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==1:
                    strjson=strjson  + """ "CWND" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==2:
                    strjson=strjson  + """ "SSTRESH" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==3:
                    strjson=strjson  + """ "RWND" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==4:
                    strjson=strjson  + """ "SRTT" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==5:
                    strjson=strjson  + """ "RTO" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==6:
                    strjson=strjson  + """ "Source IP" : """ + """ "%s" """ % (d[k][x]) + ","
                elif x==7:
                    strjson=strjson  + """ "Destination IP" : """ + """ "%s" """ % (d[k][x]) +","
                elif x==8:
                    strjson=strjson  + """ "LENGTH" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==9:
                    strjson=strjson  + """ "RTTVAR" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==10:
                    strjson=strjson  + """ "LOST" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==11:
                    strjson=strjson  + """ "RETRANSMIT" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==12:
                    strjson=strjson  + """ "INFLIGHT" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==13:
                    strjson=strjson  + """ "FRTO" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==14:
                    strjson=strjson  + """ "RQUEUE" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==15:
                    strjson=strjson  + """ "WQUEUE" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==16:
                    strjson=strjson  + """ "FIRSTSEQ" : """ + """ "%s" """ % (str(d[k][x])) +","
                elif x==17:
                    strjson=strjson  + """ "LASTUNACKSEQ" : """ + """ "%s" """ % (str(d[k][x]))
        strjson=strjson  + ' } '   + ' , '               
    strjson = strjson[:-2]
    strjson=strjson + ']'
    return HttpResponse(strjson)


def readTcpFlow(filepath,PortNo):
        count = 0
        #return "Hello, world...4"
        #print 'read tcpfile ',current_thread()
        
        while(True):
                global isactive
                #print 'before brek'
                #print isactive
                if  isactive != 1:
                    break;
            
                if os.path.exists(filepath):
                        #print 'path exist'
                        with open(filepath) as f:
                                #print 'file opend'
                                while (True and isactive == 1):
                                        line= f.readline()
                                        if len(line)==0:
                                                break
                                        #count = count+1
                                        addDataToQueue(line,PortNo)
                                        #print count,' ',line,
                                        #print '*****'
        
def addDataToQueue(stream,PortNo):
    currentTime=strftime("%Y-%m-%d %H:%M:%S", gmtime())
    lstItem=[currentTime] + stream.split()
    global qConn
    lstOFIpAndPORT=lstItem[2].split(':')
    
    if (str(lstOFIpAndPORT[1])!=PortNo):
        #print lstOFIpAndPORT[1] 
        #print lstItem
        qConn.put(lstItem)
    if not qConn.empty():
        #print qConn.qsize()
        try:
            firstElementTime=(list(qConn.queue))[0][0]
        except:
            firstElementTime=currentTime
        #print firstElementTime
        from dateutil.parser import parse
        parseFirstElementTime = parse(firstElementTime)
        parseCurrentTime = parse(currentTime)
        diffOfTime = parseCurrentTime - parseFirstElementTime
        timeBuffer=diffOfTime.total_seconds()
        #print timeBuffer
        #if timeBuffer>=30:
        if timeBuffer>=60:
            global isactive
            #isactive=0
            global qConn
            with qConn.mutex:
                qConn.queue.clear()
            
            
            
    #print '+++++++++++++++++++++++++++++++++++++++',lstItem
    

def startThread(request,switch):
    global isactive
    global threads
    try:
        

        #print 'start thread ',current_thread()
        if switch == "1" and isactive!=1:
            isactive=1
            #dataFetcher=Thread(target=readTcpFlow, args=('/proc/net/tcpflow',str(request.META['SERVER_PORT'])))
            dataFetcher=Thread(target=readTcpFlow, args=('/proc/net/tcpprobe',str(request.META['SERVER_PORT'])))
            #dataFetcher.setDaemon(True)
            dataFetcher.start()            
            #threads.append(dataFetcher)
            return HttpResponse("Thread started.")
        elif switch=="0" and isactive==1:
            #threads[0].setDaemon(True)
            #threads[0]._Thread__stop()
            #threads[0].join(1)
            isactive=0 
            #del threads[:]
            global qConn
            with qConn.mutex:
                qConn.queue.clear()
            return HttpResponse(" thread stoped.  " )

        elif switch=="0" and isactive==0:
            return HttpResponse("There  is no running thread to stop")
        elif switch=="1" and isactive==1:
            return HttpResponse("Thread is already running So can't start a new thread")
                          
            #dataFetcher.setDaemon(True)
            #a=1         
    except:
            #print "Hello, world...5"
            return HttpResponse("Hello, Exception." + traceback.format_exc())
