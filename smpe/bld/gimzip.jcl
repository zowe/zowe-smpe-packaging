//GIMZIP   JOB
//GIMZIP   EXEC PGM=GIMZIP,PARM='#gimzipParm',REGION=0M,COND=(0,LT)
//*STEPLIB  DD DISP=SHR,DSN=SYS1.MIGLIB
//SYSUT2   DD UNIT=SYSALLDA,SPACE=(CYL,(200,100))
//SYSUT3   DD UNIT=SYSALLDA,SPACE=(CYL,(50,10))
//SYSUT4   DD UNIT=SYSALLDA,SPACE=(CYL,(25,5))
//SMPOUT   DD DISP=SHR,DSN=#gimzipHlq.SMPOUT
//SYSPRINT DD DISP=MOD,DSN=#gimzipHlq.SYSPRINT
//* package directory
//SMPDIR   DD PATHDISP=KEEP,
// PATH='#dir/SMPDIR'    
//* smp classes directory
//SMPCPATH DD PATHDISP=KEEP,
// PATH='#dir/SMPCPATH'  
//* java runtime directory
//SMPJHOME DD PATHDISP=KEEP,
// PATH='#dir/SMPJHOME'  
//* work directory
//SMPWKDIR DD PATHDISP=KEEP,
// PATH='#dir/SMPWKDIR'  
//* package control tags
//SYSIN    DD DISP=SHR,DSN=#gimzipHlq.SYSIN       