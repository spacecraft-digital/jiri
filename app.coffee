
config = require './config'

Jira = require './src/Jira'

JiriSlack = require './src/JiriSlack'

Jiri = require './src/Jiri'

############

jira = new Jira config

slack = new JiriSlack(
    config.slack_apiToken,
    config.slack_autoReconnect,
    config.slack_autoMark
)

############

jiri = new Jiri slack, jira, db
