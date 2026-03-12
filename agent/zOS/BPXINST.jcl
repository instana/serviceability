//* ***************************************************************
//* execute a uss script (SH) or command in batch
//* ***************************************************************
//BPXBAT1 PROC    
//BPXIT    EXEC PGM=BPXBATCH, REGION=0M, TIME=NOLIMIT,  
//  PARM='SH /u/neha/c/localbuild/instana-agent/bin/startb',
//*
//STDOUT   DD SYSOUT=*
//STDERR   DD SYSOUT=*
