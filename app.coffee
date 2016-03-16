
config = require './config'
JiriSlack = require './src/JiriSlack'

jira = new (require './src/Jira') config
Jiri = require './src/Jiri'

slack = new JiriSlack(
    config.slack_apiToken,
    config.slack_autoReconnect,
    config.slack_autoMark
)

gitlab = (require 'gitlab')
  url:   config.gitlab_url
  token: config.gitlab_token

############

jiri = new Jiri slack, jira, gitlab
