//GIMZIP   JOB
//GIMZIP   EXEC PGM=GIMZIP,PARM='#gimzipParm',REGION=0M,COND=(0,LT)
//*STEPLIB  DD DISP=SHR,DSN=SYS1.MIGLIB
//SYSUT2   DD UNIT=SYSALLDA,SPACE=(CYL,(200,100))
//SYSUT3   DD UNIT=SYSALLDA,SPACE=(CYL,(50,10))
//SYSUT4   DD UNIT=SYSALLDA,SPACE=(CYL,(25,5))
//SMPOUT   DD DISP=SHR,DSN=#gimzipHlq.SMPOUT
//SYSPRINT DD DISP=MOD,DSN=#gimzipHlq.SYSPRINT
//SMPDIR   DD PATHDISP=KEEP,PATH='#dir/SMPDIR'    package directory
//SMPCPATH DD PATHDISP=KEEP,PATH='#dir/SMPCPATH'  smp classes directory
//SMPJHOME DD PATHDISP=KEEP,PATH='#dir/SMPJHOME'  java runtime directory
//SMPWKDIR DD PATHDISP=KEEP,PATH='#dir/SMPWKDIR'  work directory
//SYSIN    DD DISP=SHR,DSN=#gimzipHlq.SYSIN       package control tags