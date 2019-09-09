# Template Language for Generating JCLs

I would like to propose using a template language to generate installation JCLs.
There are various template languages for example [VTL Velocity Template Language](https://velocity.apache.org/engine/1.7/vtl-reference.html) an Apache project. 
VTL is used in z/OSMF workflows (https://www.ibm.com/support/knowledgecenter/en/SSLTBW_2.1.0/com.ibm.zos.v2r1.izua700/izuprog_WorkflowsXML_VariablesVelocity.htm)

## Problem Statement
Currently we package `ZWE2RCVE` JCL 
https://github.com/zowe/zowe-smpe-packaging/blob/master/smpe/pax/MVS/ZWE2RCVE.jcl that has to be customized
 - during build process before it is packaged `[FMID]`. 
 - by customer before it is submitted `#hlq, #csihlq`. Moreover certain variables have to be copy-pasted to other JCL eg `#csihlq`.

```jcl
//         SET HLQ=#hlq
//*
//RECEIVE  EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=#csihlq.CSI
//*SMPTLIB  DD UNIT=SYSALLDA,SPACE=(TRK,(1,1)),VOL=SER=#csivol
//SMPHOLD  DD DUMMY
//SMPPTFIN DD DISP=SHR,DSN=&HLQ..[RFDSNPFX].[FMID].SMPMCS
//SMPCNTL  DD *,SYMBOLS=JCLONLY
   SET BOUNDARY(GLOBAL) .
   RECEIVE SELECT([FMID])
           SYSMODS
           RFPREFIX(&HLQ)
           LIST .
//*
```

## Solution 
Petr Plavjanik developed [vtl-cli](https://github.com/plavjanik/vtl-cli) that allows to execute velocity translation from command line. Tool is written in java.

We can create one JCL template that could be used to 
 1) generate JCL (on Marist) that we package in SMPE pax (that complies to IBM packaging standards)
 2) generate customized JCL that could be submitted by customer
 3) generate a JCL that could be executed within z/OSMF workflow

We can adopt VTL for configuration of Zowe, this allows use
 - to build configuration workflows
 - perform reconfiguration of an existing Zowe instance
 - automate configuration via CLI

### Examples
With single template (/example/ZWE2RCVE.vlt) we can generate multiple output files.

```
#if(${instance-jobcard})//ZWE2RCVE JOB ${instance-jobcard}
#end
//*
//* This program and the accompanying materials are made available
...
//         EXPORT SYMLIST=(HLQ)
//*
//         SET HLQ=${instance-hlq}
//*
//RECEIVE  EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=${instance-csihlq}.CSI
//*SMPTLIB  DD UNIT=SYSALLDA#if(! ("$!{instance-csivol}"=="")),VOL=SER=${instance-csivol}#end,SPACE=(TRK,(1,1))
//SMPHOLD  DD DUMMY
//SMPPTFIN DD DISP=SHR,DSN=&HLQ..[RFDSNPFX].[FMID].SMPMCS
//SMPCNTL  DD *,SYMBOLS=JCLONLY
   SET BOUNDARY(GLOBAL) .
   RECEIVE SELECT([FMID])
           SYSMODS
           RFPREFIX(&HLQ)
           LIST .
//*
```
#### IBM compliant SMPE JCLs
Example of a generated IBM compliant JCL.

With this definition of variables
```yaml
instance-jobcard: "<job parameters>"
instance-csihlq: "#csihlq"
instance-hlq: "#hlq"
instance-csivol: "#csivol"
```
By running
```bash
vtl --yaml-context smpe-jcl.yaml ZWE2RCVE.vlt > ZWE2RCVE.smpe
```
We get a JCL that is packaged see `<job parameters>`, `#hlq`, `#csihlq`, `#csivol`.
```
//ZWE2RCVE JOB <job parameters>
//*
//* This program and the accompanying materials are made available
...
//         EXPORT SYMLIST=(HLQ)
//*
//         SET HLQ=#hlq
//*
//RECEIVE  EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=#csihlq.CSI
//*SMPTLIB  DD UNIT=SYSALLDA,VOL=SER=#csivol,SPACE=(TRK,(1,1))
//SMPHOLD  DD DUMMY
//SMPPTFIN DD DISP=SHR,DSN=&HLQ..[RFDSNPFX].[FMID].SMPMCS
//SMPCNTL  DD *,SYMBOLS=JCLONLY
   SET BOUNDARY(GLOBAL) .
   RECEIVE SELECT([FMID])
           SYSMODS
           RFPREFIX(&HLQ)
           LIST .
//*
```

#### Ready to be submitted JCL
```yaml
instance-jobcard: "129300000,'ZOWE SMPE EXTRACT',

  //             CLASS=C,REGION=0M,

  //             MSGLEVEL=(1,1),MSGCLASS=X,TIME=NOLIMIT

  /*JOBPARM SYSAFF=CA31"
instance-csihlq: "USR.ZOWE"
instance-hlq: "TMP.MCS"
instance-csivol: "MYVOL"  #or commented out
```
Generated output. 
```
//ZWE2RCVE JOB 129300000,'ZOWE SMPE EXTRACT',
//             CLASS=C,REGION=0M,
//             MSGLEVEL=(1,1),MSGCLASS=X,TIME=NOLIMIT
/*JOBPARM SYSAFF=CA31
//*
//* This program and the accompanying materials are made available
//         EXPORT SYMLIST=(HLQ)
//*
//         SET HLQ=TMP.MCS
//*
//RECEIVE  EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)
//SMPCSI   DD DISP=OLD,DSN=USR.ZOWE.CSI
//*SMPTLIB  DD UNIT=SYSALLDA,VOL=SER=s,SPACE=(TRK,(1,1))
//SMPHOLD  DD DUMMY
//SMPPTFIN DD DISP=SHR,DSN=&HLQ..[RFDSNPFX].[FMID].SMPMCS
//SMPCNTL  DD *,SYMBOLS=JCLONLY
   SET BOUNDARY(GLOBAL) .
   RECEIVE SELECT([FMID])
           SYSMODS
           RFPREFIX(&HLQ)
           LIST .
//*
```

#### z/OSMF workflow
 - Live demo
 - Wizard for users
 - Zowe CLI
