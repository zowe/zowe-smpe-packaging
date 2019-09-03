#!groovy

/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */


node('ibm-jenkins-slave-nvm') {
  def lib = library("jenkins-library").org.zowe.jenkins_shared_library

  def pipeline = lib.pipelines.generic.GenericPipeline.new(this)

  pipeline.admins.add("jackjia")

  // we have extra parameters for integration test
  pipeline.addBuildParameter(
    booleanParam(
      name: 'KEEP_TEMP_FOLDER',
      description: 'If leave the temporary packaging folder on remote server.',
      defaultValue: false
    )
  )

  pipeline.setup(
    packageName : 'org.zowe.smpe',
    version     : '1.4.0',
    github: [
      email                      : lib.Constants.DEFAULT_GITHUB_ROBOT_EMAIL,
      usernamePasswordCredential : lib.Constants.DEFAULT_GITHUB_ROBOT_CREDENTIAL,
    ],
    artifactory: [
      url                        : lib.Constants.DEFAULT_ARTIFACTORY_URL,
      usernamePasswordCredential : lib.Constants.DEFAULT_ARTIFACTORY_ROBOT_CREDENTIAL,
    ],
    pax: [
      // sshHost                    : 'river.zowe.org',
      // sshPort                    : '2022',
      // sshCredential              : 'ssh-zdt-test-image-guest',
      // remoteWorkspace            : '/zaas1',
      sshHost                    : lib.Constants.DEFAULT_PAX_PACKAGING_SSH_HOST,
      sshPort                    : lib.Constants.DEFAULT_PAX_PACKAGING_SSH_PORT,
      sshCredential              : lib.Constants.DEFAULT_PAX_PACKAGING_SSH_CREDENTIAL,
      remoteWorkspace            : lib.Constants.DEFAULT_PAX_PACKAGING_REMOTE_WORKSPACE,
    ]
  )

  pipeline.build(
    timeout       : [time: 5, unit: 'MINUTES'],
    isSkippable   : false,
    operation     : {
      pipeline.artifactory.download(
        spec        : 'artifactory-download-spec.json.template',
        expected    : 2
      )
    }
  )

  // FIXME: we may move smoke test into this pipeline
  pipeline.test(
    name              : "Smoke",
    operation         : {
        echo 'Skip until test case are embeded into this pipeline.'
    },
    allowMissingJunit : true
  )

  pipeline.packaging(
    name          : "zowe-smpe",
    timeout       : [time: 60, unit: 'MINUTES'],
    operation: {
      pipeline.pax.pack(
          job             : "zowe-smpe-packaging",
          filename        : 'zowe-smpe.pax',
          environments    : [ 'ZOWE_VERSION': pipeline.getVersion() ],
          extraFiles      : 'readme.txt,rename-back.sh',
          keepTempFolder  : params.KEEP_TEMP_FOLDER
      )
      // rename to correct suffix
      sh "cd .pax && chmod +x rename-back.sh && cat rename-back.sh && ./rename-back.sh"
    }
  )

  // define we need publish stage
  pipeline.publish(
    artifacts: [
      '.pax/AZWE*'
    ]
  )

  pipeline.end()
}
