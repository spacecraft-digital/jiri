
config = require './config'

db = require './src/db'

JiraApi = require('jira').JiraApi
JiriSlack = require './src/JiriSlack'

Jiri = require './src/Jiri'

############

jira = new JiraApi(
    config.jira_protocol,
    config.jira_host,
    config.jira_port,
    config.jira_user,
    config.jira_password,
    'latest',
    true
)

slack = new JiriSlack(
    config.slack_apiToken,
    config.slack_autoReconnect,
    config.slack_autoMark
)

############

jiri = new Jiri slack, jira, db
