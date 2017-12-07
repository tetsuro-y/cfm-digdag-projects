import groovy.json.JsonOutput

def notifySlack(text, channel, attachments) {
    def slackURL = 'https://hooks.slack.com/services/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'
    def jenkinsIcon = 'https://wiki.jenkins-ci.org/download/attachments/2916393/logo.png'

    def payload = JsonOutput.toJson([text: text,
        channel: channel,
        username: "Jenkins",
        icon_url: jenkinsIcon,
        attachments: attachments
    ])

    sh "curl -X POST --data-urlencode \'payload=${payload}\' ${slackURL}"
}

def getLastCommitMessage = {
    return sh(returnStdout: true, script: 'git log -1 --pretty=%B').trim()
}

def getGitAuthor = {
    def commit = sh(returnStdout: true, script: 'git rev-parse HEAD')
    msg = sh(returnStdout: true, script: "git --no-pager show -s --format='%an' ${commit}").trim()
    url = "http://10.201.161.10:8084/CFM/AutoDigdagProject/commit/${commit}"
    return msg + '\n' + url
}

node {
    stage('Checkout') {
        git url: env.GITBUCKET_URL + "/CFM/AutoDigdagProject.git", branch: env.BRANCH_NAME
    }

    stage('Build') {
        def jobName = "${env.JOB_NAME}"
        def title = "${jobName}, build branch #${env.BUILD_NUMBER}"
        def type = ''
        def buildmessage = ''
        def deploymessage = ''
        try {
            type = 'build pushed branch'
            sh './tests/test.sh > buildmessage'

            if (env.BRANCH_NAME == 'master') {
                type = 'build & deply master branch'
                sh './deploy/deploy.sh > deploymessage'
            }
        } catch (err) {
            echo "Build Failed"
            currentBuild.result = "FAILURE"
        } finally {
            if(currentBuild.result != "FAILURE") {
                echo "Build Success"
                currentBuild.result = "SUCCESS"
            }

            def message = getLastCommitMessage();
            def buildColor = currentBuild.result == "SUCCESS" ? "good" : "danger"
            def author = getGitAuthor();
            def slackNotificationChannel = '#cfm_team'

            if(fileExists('./buildmessage')) {
                buildmessage = readFile('./buildmessage').trim()
            }

            if(fileExists('./deploymessage')) {
                deploymessage = readFile('deploymessage').trim()
            }

            def summary = deploymessage == '' ? buildmessage : deploymessage;

            notifySlack("", slackNotificationChannel, [
                [
                    title: "[${currentBuild.result}] Jenkins CI",
                    color: "${buildColor}",
                    text: "${title}\n${env.BUILD_URL}console",
                    "mrkdwn_in": ["fields"],
                    fields: [
                        [
                            title: "Branch",
                            value: "${env.BRANCH_NAME}",
                            short: true
                        ],
                        [
                            title: "Type",
                            value: "${type}",
                            short: true
                        ],
                        [
                            title: "Last Commit",
                            value: "${message} by ${author}",
                            short: false
                        ],
                        [
                            title: "Output",
                            value: "``` ${summary} ```",
                            short: false
                        ]
                    ]
                ]
            ])
        }
    }
}

