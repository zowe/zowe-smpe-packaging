//ZWE0CLN  JOB <job parameters>
//*
//* This program and the accompanying materials are made available
//* under the terms of the Eclipse Public License v2.0 which
//* accompanies this distribution, and is available at
//* https://www.eclipse.org/legal/epl-v20.html
//*
//* SPDX-License-Identifier: EPL-2.0
//*
//* Copyright Contributors to the Zowe Project. 2019, [YEAR]
//*
//*********************************************************************
//*
//* This JCL is used to cleanup HLQ for CSI and SMP/E datasets.
//*
//*
//* CAUTION: This is neither a JCL procedure nor a complete job.
//* Before using this job step, you will have to make the following
//* modifications:
//*
//* 1) Add the job parameters to meet your system requirements.
//*
//* 2) Change #csihlq to the high level qualifier for the CSI and
//*    other SMP/E data sets. The maximum length is 35 characters.
//*
//*
//* Note(s):
//*
//* 1. This job utilizes JCL variables inside inline text, which
//*    requires z/OS 2.1 or higher. When using an older z/OS level,
//*    - Comment out the EXPORT SYMLIST statement
//*    - Remove ",SYMBOLS=JCLONLY" from the DD definitions that 
//*      utilize inline JCL variables
//*    - Replace the following variables with their actual value:
//*      - step CLEANUP, DD SYSIN, variable &CSIHLQ. (1 time)
//*
//* 2. This job should complete with a return code 0.
//*
//*********************************************************************
//         EXPORT SYMLIST=(CSIHLQ)
//*                            1         2         3
//*                   12345678901234567890123456789012345
//         SET CSIHLQ=#csihlq
//*
//* CLEANUP HLQ
//*
//CLEANUP  EXEC  PGM=ADRDSSU,REGION=2048K                        
//SYSPRINT DD  SYSOUT=*                                         
//DELETE   DD  DUMMY
//SYSIN    DD  *,SYMBOLS=JCLONLY                                                
 DUMP DATASET(INCLUDE(&CSIHLQ..** )) -                  
    OUTDD(DELETE) DELETE  
