# IBM MQ Must Gather Script

## Overview

The `mq_status.sh` script will collect the configuration data from running IBM MQ

## Usage

1. Copy the script to the environment where ibm mq is running
2. Make the scirpt executable.
   
   ```bash
   chmod +x mq_status.sh
   ```
3. Run the script

   ```bash
   . /opt/mqm/bin/setmqenv -s
   ./mq_status.sh QueueManagerName
   ```

   This will display the below details:
   - Queue manager definition and status
   - Channel definition and status - Look for only CHLTYPE(SVRCONN) which is what we need in agent configuration
   - Listener definition and status – Check the port and status
   
## Script output example
   ```bash
   root@ibmmq1:~# ./mq_status.sh QM1
Version: 1.0.0
Queue Manager Definition and Status:
5724-H72 (C) Copyright IBM Corp. 1994, 2025.
Starting MQSC for queue manager QM1.


     1 : DISPLAY QMGR ALL
AMQ8408I: Display Queue Manager details.
   QMNAME(QM1)                             ACCTCONO(DISABLED)
   ACCTINT(1800)                           ACCTMQI(OFF)
   ACCTQ(OFF)                              ACTIVREC(MSG)
   ACTVCONO(DISABLED)                      ACTVTRC(OFF)
   ADVCAP(ENABLED)                         ALTDATE(2025-04-22)
   ALTTIME(05.42.38)                       AMQPCAP(YES)
   AUTHOREV(DISABLED)                      CCSID(1208)
   CERTLABL(ibmwebspheremqqm1)             CERTVPOL(ANY)
   CHAD(DISABLED)                          CHADEV(DISABLED)
   CHADEXIT( )                             CHLEV(DISABLED)
   CHLAUTH(DISABLED)                       CLWLDATA( )
   CLWLEXIT( )                             CLWLLEN(100)
   CLWLMRUC(999999999)                     CLWLUSEQ(LOCAL)
   CMDEV(DISABLED)                         CMDLEVEL(942)
   COMMANDQ(SYSTEM.ADMIN.COMMAND.QUEUE)    CONFIGEV(DISABLED)
   CONNAUTH(DEV.AUTHINFO)                  CRDATE(2025-04-22)
   CRTIME(03.01.05)                        CUSTOM( )
   DEADQ(DEV.DEAD.LETTER.QUEUE)            DEFCLXQ(SCTQ)
   DEFXMITQ( )                             DESCR( )
   DISTL(YES)                              IMGINTVL(60)
   IMGLOGLN(OFF)                           IMGRCOVO(YES)
   IMGRCOVQ(YES)                           IMGSCHED(MANUAL)
   INHIBTEV(DISABLED)                      INITKEY( )
   IPADDRV(IPV4)                           LOCALEV(DISABLED)
   LOGGEREV(DISABLED)                      MARKINT(5000)
   MAXHANDS(256)                           MAXMSGL(4194304)
   MAXPROPL(NOLIMIT)                       MAXPRTY(9)
   MAXUMSGS(10000)                         MONACLS(QMGR)
   MONCHL(OFF)                             MONQ(OFF)
   PARENT( )                               PERFMEV(DISABLED)
   PLATFORM(UNIX)                          PSMODE(ENABLED)
   PSCLUS(ENABLED)                         PSNPMSG(DISCARD)
   PSNPRES(NORMAL)                         PSRTYCNT(5)
   PSSYNCPT(IFPER)                         QMID(QM1_2025-04-22_03.01.05)
   REMOTEEV(DISABLED)                      REPOS( )
   REPOSNL( )                              REVDNS(ENABLED)
   ROUTEREC(MSG)                           SCHINIT(QMGR)
   SCMDSERV(QMGR)                          SPLCAP(ENABLED)
   SSLCRLNL( )                             SSLCRYP( )
   SSLEV(DISABLED)                         SSLFIPS(NO)
   KEYRPWD( )                              SSLKEYR(/var/mqm/qmgrs/QM1/ssl/key)
   SSLRKEYC(0)                             STATACLS(QMGR)
   STATCHL(OFF)                            STATINT(1800)
   STATMQI(OFF)                            STATQ(OFF)
   STRSTPEV(ENABLED)                       SUITEB(NONE)
   SYNCPT                                  TREELIFE(1800)
   TRIGINT(999999999)                      VERSION(09040200)
   XRCAP(YES)
One MQSC command read.
No commands have a syntax error.
All valid MQSC commands were processed.
5724-H72 (C) Copyright IBM Corp. 1994, 2025.
Starting MQSC for queue manager QM1.


     1 : DISPLAY QMSTATUS ALL
AMQ8705I: Display Queue Manager Status Details.
   QMNAME(QM1)                             TYPE(QMGR)
   STATUS(RUNNING)                         AUTOCLUS(NONE)
   CHINIT(RUNNING)                         CHKPTCNT(217)
   CHKPTOPS(474)                           CHKPTSZ(0)
   CMDSERV(RUNNING)                        CONNS(24)
   DATFSSZ(SHARED)                         DATFSUSE(SHARED)
   DATPATH(/var/mqm/qmgrs/QM1)             DISKLSN(<0:0:27:53638>)
   GRPLSN( )                               GRPNAME( )
   GRPROLE(NOTCONFIG)                      HOSTNAME(ibmmq1)
   INSTANCE( )                             INSTDESC( )
   INSTNAME(Installation1)                 INSTPATH(/opt/mqm)
   LDAPCONN(INACTIVE)                      LOGEXTSZ(16392)
   LOGFSSZ(SHARED)                         LOGFSUSE(SHARED)
   LOGINUSE(5)                             LOGPATH(/var/mqm/log/QM1/active/)
   LOGPRIM(3)                              LOGSEC(2)
   LOGSTRDA(2025-04-26)                    LOGSTRL(<0:0:27:13701>)
   LOGSTRTI(11:32:56)                      LOGTYPE(CIRCULAR)
   LOGUTIL(5)                              QMFSSZ(253824)
   QMFSUSE(11)                             QUORUM( )
   REUSESZ(0)                              STANDBY(NOPERMIT)
   STARTDA(2025-04-27)                     STARTTI(03.38.01)
   UNICLUS( )
One MQSC command read.
No commands have a syntax error.
All valid MQSC commands were processed.

Channel Definitions:
5724-H72 (C) Copyright IBM Corp. 1994, 2025.
Starting MQSC for queue manager QM1.


     1 : DISPLAY CHANNEL(*) ALL
AMQ8414I: Display Channel details.
   CHANNEL(DEV.ADMIN.SVRCONN)              CHLTYPE(SVRCONN)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.08)
   CERTLABL( )                             COMPHDR(NONE)
   COMPMSG(NONE)                           DESCR( )
   DISCINT(0)                              HBINT(300)
   KAINT(AUTO)                             MAXINST(999999999)
   MAXINSTC(999999999)                     MAXMSGL(4194304)
   MCAUSER( )                              MONCHL(QMGR)
   RCVDATA( )                              RCVEXIT( )
   SCYDATA( )                              SCYEXIT( )
   SENDDATA( )                             SENDEXIT( )
   SHARECNV(10)                            SSLCAUTH(REQUIRED)
   SSLCIPH( )                              SSLPEER( )
   TRPTYPE(TCP)
AMQ8414I: Display Channel details.
   CHANNEL(DEV.APP.SVRCONN)                CHLTYPE(SVRCONN)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.08)
   CERTLABL( )                             COMPHDR(NONE)
   COMPMSG(NONE)                           DESCR( )
   DISCINT(0)                              HBINT(300)
   KAINT(AUTO)                             MAXINST(999999999)
   MAXINSTC(999999999)                     MAXMSGL(4194304)
   MCAUSER(app)                            MONCHL(QMGR)
   RCVDATA( )                              RCVEXIT( )
   SCYDATA( )                              SCYEXIT( )
   SENDDATA( )                             SENDEXIT( )
   SHARECNV(10)                            SSLCAUTH(REQUIRED)
   SSLCIPH( )                              SSLPEER( )
   TRPTYPE(TCP)
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.ADMIN.SVRCONN)           CHLTYPE(SVRCONN)
   ALTDATE(2025-04-22)                     ALTTIME(05.40.49)
   CERTLABL( )                             COMPHDR(NONE)
   COMPMSG(NONE)                           DESCR( )
   DISCINT(0)                              HBINT(300)
   KAINT(AUTO)                             MAXINST(999999999)
   MAXINSTC(999999999)                     MAXMSGL(4194304)
   MCAUSER( )                              MONCHL(QMGR)
   RCVDATA( )                              RCVEXIT( )
   SCYDATA( )                              SCYEXIT( )
   SENDDATA( )                             SENDEXIT( )
   SHARECNV(10)                            SSLCAUTH(REQUIRED)
   SSLCIPH( )                              SSLPEER( )
   TRPTYPE(TCP)
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.AUTO.RECEIVER)           CHLTYPE(RCVR)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.06)
   BATCHSZ(50)                             CERTLABL( )
   COMPHDR(NONE)                           COMPMSG(NONE)
   DESCR(Auto-defined by)                  HBINT(300)
   KAINT(AUTO)                             MAXMSGL(4194304)
   MCAUSER( )                              MONCHL(QMGR)
   MRDATA( )                               MREXIT( )
   MRRTY(10)                               MRTMR(1000)
   MSGDATA( )                              MSGEXIT( )
   NPMSPEED(FAST)                          PUTAUT(DEF)
   RCVDATA( )                              RCVEXIT( )
   RESETSEQ(NO)                            SCYDATA( )
   SCYEXIT( )                              SENDDATA( )
   SENDEXIT( )                             SEQWRAP(999999999)
   SSLCAUTH(REQUIRED)                      SSLCIPH( )
   SSLPEER( )                              STATCHL(QMGR)
   TRPTYPE(TCP)                            USEDLQ(YES)
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.AUTO.SVRCONN)            CHLTYPE(SVRCONN)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.06)
   CERTLABL( )                             COMPHDR(NONE)
   COMPMSG(NONE)                           DESCR(Auto-defined by)
   DISCINT(0)                              HBINT(300)
   KAINT(AUTO)                             MAXINST(999999999)
   MAXINSTC(999999999)                     MAXMSGL(4194304)
   MCAUSER( )                              MONCHL(QMGR)
   RCVDATA( )                              RCVEXIT( )
   SCYDATA( )                              SCYEXIT( )
   SENDDATA( )                             SENDEXIT( )
   SHARECNV(10)                            SSLCAUTH(REQUIRED)
   SSLCIPH( )                              SSLPEER( )
   TRPTYPE(TCP)
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.DEF.AMQP)                CHLTYPE(AMQP)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.07)
   CERTLABL( )                             DESCR( )
   AMQPKA(AUTO)                            LOCLADDR( )
   MAXINST(999999999)                      MAXMSGL(4194304)
   MCAUSER( )                              PORT(5672)
   SSLCAUTH(REQUIRED)                      SSLCIPH( )
   SSLPEER( )                              TPROOT(SYSTEM.BASE.TOPIC)
   TMPMODEL(SYSTEM.DEFAULT.MODEL.QUEUE)    TMPQPRFX(AMQP.*)
   USECLTID(NO)
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.DEF.CLUSRCVR)            CHLTYPE(CLUSRCVR)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.06)
   BATCHHB(0)                              BATCHINT(0)
   BATCHLIM(5000)                          BATCHSZ(50)
   CERTLABL( )                             CLUSNL( )
   CLUSTER( )                              CLWLPRTY(0)
   CLWLRANK(0)                             CLWLWGHT(50)
   COMPHDR(NONE)                           COMPMSG(NONE)
   CONNAME( )                              CONVERT(NO)
   DESCR( )                                DISCINT(6000)
   HBINT(300)                              KAINT(AUTO)
   LOCLADDR( )                             LONGRTY(999999999)
   LONGTMR(1200)                           MAXMSGL(4194304)
   MCANAME( )                              MCATYPE(THREAD)
   MCAUSER( )                              MODENAME( )
   MONCHL(QMGR)                            MRDATA( )
   MREXIT( )                               MRRTY(10)
   MRTMR(1000)                             MSGDATA( )
   MSGEXIT( )                              NETPRTY(0)
   NPMSPEED(FAST)                          PROPCTL(COMPAT)
   PUTAUT(DEF)                             RCVDATA( )
   RCVEXIT( )                              RESETSEQ(NO)
   SCYDATA( )                              SCYEXIT( )
   SENDDATA( )                             SENDEXIT( )
   SEQWRAP(999999999)                      SHORTRTY(10)
   SHORTTMR(60)                            SSLCAUTH(REQUIRED)
   SSLCIPH( )                              SSLPEER( )
   STATCHL(QMGR)                           TPNAME( )
   TRPTYPE(TCP)                            USEDLQ(YES)
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.DEF.CLUSSDR)             CHLTYPE(CLUSSDR)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.06)
   BATCHHB(0)                              BATCHINT(0)
   BATCHLIM(5000)                          BATCHSZ(50)
   CLUSNL( )                               CLUSTER( )
   CLWLPRTY(0)                             CLWLRANK(0)
   CLWLWGHT(50)                            COMPHDR(NONE)
   COMPMSG(NONE)                           CONNAME( )
   CONVERT(NO)                             DESCR( )
   DISCINT(6000)                           HBINT(300)
   KAINT(AUTO)                             LOCLADDR( )
   LONGRTY(999999999)                      LONGTMR(1200)
   MAXMSGL(4194304)                        MCANAME( )
   MCATYPE(THREAD)                         MCAUSER( )
   MODENAME( )                             MONCHL(QMGR)
   MSGDATA( )                              MSGEXIT( )
   NPMSPEED(FAST)                          PASSWORD( )
   PROPCTL(COMPAT)                         RCVDATA( )
   RCVEXIT( )                              RESETSEQ(NO)
   SCYDATA( )                              SCYEXIT( )
   SENDDATA( )                             SENDEXIT( )
   SEQWRAP(999999999)                      SHORTRTY(10)
   SHORTTMR(60)                            SSLCIPH( )
   SSLPEER( )                              STATCHL(QMGR)
   TPNAME( )                               TRPTYPE(TCP)
   USEDLQ(YES)                             USERID( )
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.DEF.RECEIVER)            CHLTYPE(RCVR)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.06)
   BATCHSZ(50)                             CERTLABL( )
   COMPHDR(NONE)                           COMPMSG(NONE)
   DESCR( )                                HBINT(300)
   KAINT(AUTO)                             MAXMSGL(4194304)
   MCAUSER( )                              MONCHL(QMGR)
   MRDATA( )                               MREXIT( )
   MRRTY(10)                               MRTMR(1000)
   MSGDATA( )                              MSGEXIT( )
   NPMSPEED(FAST)                          PUTAUT(DEF)
   RCVDATA( )                              RCVEXIT( )
   RESETSEQ(NO)                            SCYDATA( )
   SCYEXIT( )                              SENDDATA( )
   SENDEXIT( )                             SEQWRAP(999999999)
   SSLCAUTH(REQUIRED)                      SSLCIPH( )
   SSLPEER( )                              STATCHL(QMGR)
   TRPTYPE(TCP)                            USEDLQ(YES)
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.DEF.REQUESTER)           CHLTYPE(RQSTR)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.06)
   BATCHSZ(50)                             CERTLABL( )
   COMPHDR(NONE)                           COMPMSG(NONE)
   CONNAME( )                              DESCR( )
   HBINT(300)                              KAINT(AUTO)
   LOCLADDR( )                             MAXMSGL(4194304)
   MCANAME( )                              MCATYPE(PROCESS)
   MCAUSER( )                              MODENAME( )
   MONCHL(QMGR)                            MRDATA( )
   MREXIT( )                               MRRTY(10)
   MRTMR(1000)                             MSGDATA( )
   MSGEXIT( )                              NPMSPEED(FAST)
   PASSWORD( )                             PUTAUT(DEF)
   RCVDATA( )                              RCVEXIT( )
   RESETSEQ(NO)                            SCYDATA( )
   SCYEXIT( )                              SENDDATA( )
   SENDEXIT( )                             SEQWRAP(999999999)
   SSLCAUTH(REQUIRED)                      SSLCIPH( )
   SSLPEER( )                              STATCHL(QMGR)
   TPNAME( )                               TRPTYPE(TCP)
   USEDLQ(YES)                             USERID( )
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.DEF.SENDER)              CHLTYPE(SDR)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.06)
   BATCHHB(0)                              BATCHINT(0)
   BATCHLIM(5000)                          BATCHSZ(50)
   CERTLABL( )                             COMPHDR(NONE)
   COMPMSG(NONE)                           CONNAME( )
   CONVERT(NO)                             DESCR( )
   DISCINT(6000)                           HBINT(300)
   KAINT(AUTO)                             LOCLADDR( )
   LONGRTY(999999999)                      LONGTMR(1200)
   MAXMSGL(4194304)                        MCANAME( )
   MCATYPE(PROCESS)                        MCAUSER( )
   MODENAME( )                             MONCHL(QMGR)
   MSGDATA( )                              MSGEXIT( )
   NPMSPEED(FAST)                          PASSWORD( )
   PROPCTL(COMPAT)                         RCVDATA( )
   RCVEXIT( )                              RESETSEQ(NO)
   SCYDATA( )                              SCYEXIT( )
   SENDDATA( )                             SENDEXIT( )
   SEQWRAP(999999999)                      SHORTRTY(10)
   SHORTTMR(60)                            SSLCIPH( )
   SSLPEER( )                              STATCHL(QMGR)
   TPNAME( )                               TRPTYPE(TCP)
   USEDLQ(YES)                             USERID( )
   XMITQ( )
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.DEF.SERVER)              CHLTYPE(SVR)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.06)
   BATCHHB(0)                              BATCHINT(0)
   BATCHLIM(5000)                          BATCHSZ(50)
   CERTLABL( )                             COMPHDR(NONE)
   COMPMSG(NONE)                           CONNAME( )
   CONVERT(NO)                             DESCR( )
   DISCINT(6000)                           HBINT(300)
   KAINT(AUTO)                             LOCLADDR( )
   LONGRTY(999999999)                      LONGTMR(1200)
   MAXMSGL(4194304)                        MCANAME( )
   MCATYPE(PROCESS)                        MCAUSER( )
   MODENAME( )                             MONCHL(QMGR)
   MSGDATA( )                              MSGEXIT( )
   NPMSPEED(FAST)                          PASSWORD( )
   PROPCTL(COMPAT)                         RCVDATA( )
   RCVEXIT( )                              RESETSEQ(NO)
   SCYDATA( )                              SCYEXIT( )
   SENDDATA( )                             SENDEXIT( )
   SEQWRAP(999999999)                      SHORTRTY(10)
   SHORTTMR(60)                            SSLCAUTH(REQUIRED)
   SSLCIPH( )                              SSLPEER( )
   STATCHL(QMGR)                           TPNAME( )
   TRPTYPE(TCP)                            USEDLQ(YES)
   USERID( )                               XMITQ( )
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.DEF.SVRCONN)             CHLTYPE(SVRCONN)
   ALTDATE(2025-04-22)                     ALTTIME(03.01.06)
   CERTLABL( )                             COMPHDR(NONE)
   COMPMSG(NONE)                           DESCR( )
   DISCINT(0)                              HBINT(300)
   KAINT(AUTO)                             MAXINST(999999999)
   MAXINSTC(999999999)                     MAXMSGL(4194304)
   MCAUSER( )                              MONCHL(QMGR)
   RCVDATA( )                              RCVEXIT( )
   SCYDATA( )                              SCYEXIT( )
   SENDDATA( )                             SENDEXIT( )
   SHARECNV(10)                            SSLCAUTH(REQUIRED)
   SSLCIPH( )                              SSLPEER( )
   TRPTYPE(TCP)
AMQ8414I: Display Channel details.
   CHANNEL(SYSTEM.DEF.CLNTCONN)            CHLTYPE(CLNTCONN)
   AFFINITY(PREFERRED)                     ALTDATE(2025-04-22)
   ALTTIME(03.01.06)                       CERTLABL( )
   CLNTWGHT(0)                             COMPHDR(NONE)
   COMPMSG(NONE)                           CONNAME( )
   DEFRECON(NO)                            DESCR( )
   HBINT(300)                              KAINT(AUTO)
   LOCLADDR( )                             MAXMSGL(4194304)
   MODENAME( )                             PASSWORD( )
   QMNAME( )                               RCVDATA( )
   RCVEXIT( )                              SCYDATA( )
   SCYEXIT( )                              SENDDATA( )
   SENDEXIT( )                             SHARECNV(10)
   SSLCIPH( )                              SSLPEER( )
   TPNAME( )                               TRPTYPE(TCP)
   USERID( )
One MQSC command read.
No commands have a syntax error.
All valid MQSC commands were processed.

Channel Statuses:
5724-H72 (C) Copyright IBM Corp. 1994, 2025.
Starting MQSC for queue manager QM1.


     1 : DISPLAY CHSTATUS(*) ALL
AMQ8420I: Channel Status not found.
One MQSC command read.
No commands have a syntax error.
One valid MQSC command could not be processed.

Listener Definitions:
5724-H72 (C) Copyright IBM Corp. 1994, 2025.
Starting MQSC for queue manager QM1.


     1 : DISPLAY LISTENER(*) ALL
AMQ8630I: Display listener information details.
   LISTENER(DEV.LISTENER.TCP)              CONTROL(QMGR)
   TRPTYPE(TCP)                            PORT(1414)
   IPADDR( )                               BACKLOG(0)
   DESCR( )                                ALTDATE(2025-04-22)
   ALTTIME(03.01.08)
AMQ8630I: Display listener information details.
   LISTENER(SYSTEM.ADMIN.LISTENER)         CONTROL(QMGR)
   TRPTYPE(TCP)                            PORT(1415)
   IPADDR( )                               BACKLOG(0)
   DESCR( )                                ALTDATE(2025-04-22)
   ALTTIME(05.40.38)
AMQ8630I: Display listener information details.
   LISTENER(SYSTEM.DEFAULT.LISTENER.TCP)   CONTROL(MANUAL)
   TRPTYPE(TCP)                            PORT(0)
   IPADDR( )                               BACKLOG(0)
   DESCR( )                                ALTDATE(2025-04-22)
   ALTTIME(03.01.06)
One MQSC command read.
No commands have a syntax error.
All valid MQSC commands were processed.

Listener Statuses:
5724-H72 (C) Copyright IBM Corp. 1994, 2025.
Starting MQSC for queue manager QM1.


     1 : DISPLAY LSSTATUS(*) ALL
AMQ8631I: Display listener status details.
   LISTENER(DEV.LISTENER.TCP)              STATUS(RUNNING)
   PID(3887)                               STARTDA(2025-04-27)
   STARTTI(03.38.01)                       DESCR( )
   TRPTYPE(TCP)                            CONTROL(QMGR)
   IPADDR(*)                               PORT(1414)
   BACKLOG(100)
AMQ8631I: Display listener status details.
   LISTENER(SYSTEM.ADMIN.LISTENER)         STATUS(RUNNING)
   PID(3890)                               STARTDA(2025-04-27)
   STARTTI(03.38.01)                       DESCR( )
   TRPTYPE(TCP)                            CONTROL(QMGR)
   IPADDR(*)                               PORT(1415)
   BACKLOG(100)
One MQSC command read.
No commands have a syntax error.
All valid MQSC commands were processed.
```
