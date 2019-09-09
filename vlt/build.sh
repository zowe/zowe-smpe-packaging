#!/bin/sh
cd example
rm -rf  ZWE2RCVE.smpe ZWE2RCVE.submit ZWE2RCVE.workflows
../bin/vtl --yaml-context smpe-jcl.yaml ZWE2RCVE.vlt > ZWE2RCVE.smpe
../bin/vtl --yaml-context submit-jcl.yaml ZWE2RCVE.vlt > ZWE2RCVE.submit
../bin/vtl --yaml-context workflow-jcl.yaml ZWE2RCVE.vlt > ZWE2RCVE.workflow