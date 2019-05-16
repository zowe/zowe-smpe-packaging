#!groovy

/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2019
 */


def isPullRequest = env.BRANCH_NAME.startsWith('PR-')
def zoweVersion = null

def opts = []
// keep last 20 builds for regular branches, no keep for pull requests
opts.push(buildDiscarder(logRotator(numToKeepStr: (isPullRequest ? '' : '20'))))
// disable concurrent build
opts.push(disableConcurrentBuilds())
// set upstream triggers
if (env.BRANCH_NAME == 'master') {
  opts.push(pipelineTriggers([
    upstream(threshold: 'SUCCESS', upstreamProjects: '/zowe-install-test')
  ]))
}

// define custom build parameters
def customParameters = []
customParameters.push(credentials(
  name: 'SERVER_CREDENTIALS_ID',
  description: 'The server credential used to create PAX file',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'TestAdminzOSaaS2',
  required: true
))
customParameters.push(string(
  name: 'SERVER_IP',
  description: 'The server IP used to create PAX file',
  defaultValue: '172.30.0.1',
  trim: true
))
customParameters.push(string(
  name: 'SERVER_PORT',
  description: 'The server port used to create PAX file',
  defaultValue: '22',
  trim: true
))
customParameters.push(string(
  name: 'ARTIFACTORY_URL',
  description: 'Artifactory URL',
  defaultValue: 'https://gizaartifactory.jfrog.io/gizaartifactory',
  trim: true,
  required: true
))
customParameters.push(credentials(
  name: 'ARTIFACTORY_SECRET',
  description: 'Artifactory access secret',
  credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  defaultValue: 'GizaArtifactory',
  required: true
))
opts.push(parameters(customParameters))

// set build properties
properties(opts)

node ('ibm-jenkins-slave-nvm-jnlp') {
  currentBuild.result = 'SUCCESS'

  try {

    stage('checkout') {
      // checkout source code
      checkout scm

      // check if it's pull request
      echo "Current branch is ${env.BRANCH_NAME}"
      if (isPullRequest) {
        echo "This is a pull request"
      }
    }

    stage('config') {
      def commitHash = sh(script: 'git rev-parse --verify HEAD', returnStdout: true).trim()

//TODO - currently hard coded against v1.1 do we need this versioning stuff longer term?
      sh """
sed -e 's#{BUILD_BRANCH}#${env.BRANCH_NAME}#g' \
    -e 's#{BUILD_NUMBER}#${env.BUILD_NUMBER}#g' \
    -e 's#{BUILD_COMMIT_HASH}#${commitHash}#g' \
    -e 's#{BUILD_TIMESTAMP}#${currentBuild.startTimeInMillis}#g' \
    manifest.json.template > manifest.json
"""
      echo "Current manifest.json is:"
      sh "cat manifest.json"

      // load zowe version from manifest
      zoweVersion = sh(
        script: "cat manifest.json | jq -r '.version'",
        returnStdout: true
      ).trim()
      if (zoweVersion) {
        echo "Packaging Zowe v${zoweVersion} started..."
      } else {
        error "Cannot find Zowe version"
      }

      // prepare JFrog CLI configurations
      withCredentials([usernamePassword(credentialsId: params.ARTIFACTORY_SECRET, passwordVariable: 'PASSWORD', usernameVariable: 'USERNAME')]) {
        sh "jfrog rt config rt-server-1 --url=${params.ARTIFACTORY_URL} --user=${USERNAME} --password=${PASSWORD}"
      }
    }

    stage('prepare') {
      // replace templates
      //TODO - currently hard coded against v1.1 do we need this versioning stuff longer term?
      echo 'replacing templates...'
      sh "sed -e 's/{ZOWE_VERSION}/${zoweVersion}/g' artifactory-download-spec.json.template > artifactory-download-spec.json && rm artifactory-download-spec.json.template"

      echo 'preparing SMPE Input...'

      // download artifactories
      sh "echo 'Effective Artifactory download spec >>>>>>>' && cat artifactory-download-spec.json"
      def downloadResult = sh(
        script: "jfrog rt dl --spec=artifactory-download-spec.json",
        returnStdout: true
      ).trim()
      echo "artifactory download result:"
      echo downloadResult
      def downloadResultObject = readJSON(text: downloadResult)
      if (downloadResultObject['status'] != 'success' ||
          downloadResultObject['totals']['success'] != 2 || downloadResultObject['totals']['failure'] != 0) {
        echo "status: ${downloadResultObject['status']}"
        echo "success: ${downloadResultObject['totals']['success']}"
        echo "failure: ${downloadResultObject['totals']['failure']}"
        error "Failed on verifying download result"
      } else {
        echo "download result is successful as expected"
      }

      // prepare folder
      // - smpe-workspace/ascii holds ascii files and will be converted to IBM-1047 encoding TODO
      sh 'mkdir -p smpe-workspace/ascii/scripts'
      sh "mkdir -p smpe-workspace/output"
      // copy from current github source
      //sh "cp -R files/* smpe-workspace/content/zowe-${zoweVersion}/files"
      //sh "rsync -rv --include '*.json' --include '*.html' --include '*.jcl' --include '*.template' --exclude '*.zip' --exclude '*.png' --exclude '*.tgz' --exclude '*.tar.gz' --exclude '*.pax' --exclude '*.jar' --prune-empty-dirs --remove-source-files pax-workspace/content/zowe-${zoweVersion}/files pax-workspace/ascii"
      sh 'cp -R scripts/* smpe-workspace/ascii/scripts'

//TODO 2a. Check codepages are correct as JCL is stored in ASCII in github and needs to be EBCDIC on river

      // debug purpose, list all files in workspace
      sh 'find ./smpe-workspace -print'
      sh 'cat ./smpe-workspace/ascii/scripts/smpe.sh'
    }

    stage('package') {
      // scp files and ssh to z/OS to pax workspace
      echo "creating smpe file from workspace..."
      timeout(time: 20, unit: 'MINUTES') {
        echo "excute smpe.sh"
        sh 'pwd; ls -al ./smpe-workspace/ascii/scripts; "./smpe-workspace/ascii/scripts/smpe.sh -?""' //TODO passing in output HLQ, output zFS folder, smpe.input location
        sh 'touch ./smpe-workspace/output/AZWE001.pax.Z'
        sh 'touch ./smpe-workspace/output/AZWE001.readme.txt'
      }
    }

    stage('publish') {

      //TODO // Upload AZWE001.pax.Z and AZWE001.readme.txt from zFS to artifactory into artifactory libs-snapshot-local/org/zowe/smpe/1.1.0/buildNoTimeStamp
      echo 'publishing pax file to artifactory...'

      def releaseIdentifier = getReleaseIdentifier()
      def buildIdentifier = getBuildIdentifier(true, '__EXCLUDE__', true)
      def buildName = env.JOB_NAME.replace('/', ' :: ')
      echo "Artifactory build name/number: ${buildName}/${env.BUILD_NUMBER}"

      // prepare build info
      sh "jfrog rt bc '${buildName}' ${env.BUILD_NUMBER}"
      // attach git information to build info
      sh "jfrog rt bag '${buildName}' ${env.BUILD_NUMBER} ."
      // upload and attach to build info

      //TODO - inject build indentifier?
      def uploadResult = sh(
        script: "jfrog rt u 'smpe-workspace/output/AZWE001.pax.Z' smpe-workspace/output/AZWE001.readme.txt' --build-name=\"${buildName}\" --build-number=${env.BUILD_NUMBER} --flat",
        returnStdout: true
      ).trim()
      echo "artifactory upload result:"
      echo uploadResult
      def uploadResultObject = readJSON(text: uploadResult)
      if (uploadResultObject['status'] != 'success' ||
          uploadResultObject['totals']['success'] != 1 || uploadResultObject['totals']['failure'] != 0) {
        error "Failed on verifying upload result"
      } else {
        echo "upload result is successful as expected"
      }
      // add environment variables to build info
      sh "jfrog rt bce '${buildName}' ${env.BUILD_NUMBER}"
      // publish build info
      sh "jfrog rt bp '${buildName}' ${env.BUILD_NUMBER} --build-url=${env.BUILD_URL}"
    }

    stage('done') {
      // send out notification
      emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} success.\n\nCheck detail: ${env.BUILD_URL}" ,
          subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} success",
          recipientProviders: [
            [$class: 'RequesterRecipientProvider'],
            [$class: 'CulpritsRecipientProvider'],
            [$class: 'DevelopersRecipientProvider'],
            [$class: 'UpstreamComitterRecipientProvider']
          ]
    }

  } catch (err) {
    currentBuild.result = 'FAILURE'

    // catch all failures to send out notification
    emailext body: "Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed.\n\nError: ${err}\n\nCheck detail: ${env.BUILD_URL}" ,
        subject: "[Jenkins] Job \"${env.JOB_NAME}\" build #${env.BUILD_NUMBER} failed",
        recipientProviders: [
          [$class: 'RequesterRecipientProvider'],
          [$class: 'CulpritsRecipientProvider'],
          [$class: 'DevelopersRecipientProvider'],
          [$class: 'UpstreamComitterRecipientProvider']
        ]

    throw err
  }
}
