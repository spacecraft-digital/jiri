
# Config — defaults can be overridden with environment vars

config =
    slack_apiToken: process.env.SLACK_API_TOKEN
    slack_autoReconnect: true
    slack_autoMark: true

    jira_protocol: 'https'
    jira_host: 'jadultd.atlassian.net'
    jira_port: '443'
    jira_user: 'jadu_support'
    jira_password: process.env.JIRA_PASSWORD
    jira_issueUrl: 'https://jadultd.atlassian.net/browse/#{key}'

    jira_status_inProgress: ['In Progress', 'WebDev in Progress', 'UX in Progress']
    jira_status_toTest: 'Testing ToDo: Spacecraft'
    jira_status_webdevToDo: 'WebDev ToDo'
    jira_status_uxToDo: 'UX ToDo'
    jira_status_awaitingMerge: ['Awaiting Merge', 'Awaiting Merge: Spacecraft']
    jira_status_readyToRelease: 'Ready for Release: Spacecraft'

    bot_name: 'Jiri'
    bot_iconUrl: 'http://res.cloudinary.com/jadu-slack/image/upload/v1434266028/jiri-icon_gmhsch.png'

    supportUrl: 'https://support.jadu.net/jadu/support/support_ticket_list.php?subject=#{ref}'

# Assert some required config
throw "SLACK_API_TOKEN needs to be set in the environment" unless config.slack_apiToken?
throw "JIRA_PASSWORD needs to be set in the environment" unless config.jira_password?

module.exports = config