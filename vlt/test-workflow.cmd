@ECHO OFF
set PTG_SYSTEM=ca32
set PTG_USER=vlcvi01

zosmf-workflow upload --workflow-path example\installWorkflow.xml  --name "Zowe Install Test" --overwrite --system CA32
@REM  --variables TEXT            list comma separated key=value pairs.
@REM  --variable-input-file TEXT  list comma separated key=value pairs.
@REM --run                       starts workflow immediately
