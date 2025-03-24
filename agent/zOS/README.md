# z/OS Pre-requisite Check and Installation Utilities


## zOS-Agent-Prereq.sh Script
This script verifies the prerequisites for installing the Instana-Agent on a z/OS environment. If any prerequisites are missing, the script will assist in downloading them.

### Usage:

#### Pre-requites to run this (zOS-Agent-Prereq.sh) Script :
Script will prompt user for the location of the latest meta-main.XXX.zos.pax.Z, example meta-main.20250319_152437.zos.pax.Z file from the asset section ( Which can be downloaded from https://github.com/zopencommunity/metaport/releases ) as shown in the below scrrenshot.
And transfer it to USS layer of z/OS.


![image1.png](image1.png)

#### Script Execution :
Execute the script from USS layer of z/OS with the user which has the root privilege.

`chmod +x ./zOS-Agent-Prereq.sh && ./zOS-Agent-Prereq.sh`

Script will prompt user for the location of the latest meta-main.XXX.zos.pax.Z, provide the path of above downloaded meta-main.XXX.zos.pax.Z file on the USS layer.

#### Output of Execution :





## WebSphere-zOS-Prereq.sh Script

This script verifies the prerequisites for WebSphere tracing(i.e. WebSphere Attach Flag is enabled) using Instana-Agent it will share the output that which all the PID's will get traced.


### Usage:
#### Script Execution :
Execute the script from USS layer of z/OS with the user which has the root privilege.

`chmod +x ./WebSphere-zOS-Prereq.sh && ./WebSphere-zOS-Prereq.sh`

#### Output of Execution :
![image2.png](image2.png)

## WebSphere-Pid-Trace-Enable.sh Script

This script checks the prerequisites for WebSphere tracing (i.e., whether the WebSphere Attach Flag is enabled) using the Instana-Agent. It prompts the user to input the PID and verifies if the flag is enabled for that PID.


### Usage:
#### Script Execution :

Execute the script from USS layer of z/OS with the user which has the root privilege.

`chmod +x ./WebSphere-Pid-Trace-Enable.sh && ./WebSphere-Pid-Trace-Enable.sh`

#### Output of Execution :
![image3.png](image3.png)
