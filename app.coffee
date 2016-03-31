
config = require './config'
JiriSlack = require './src/JiriSlack'

Jiri = require './src/Jiri'

slack = new JiriSlack(
    config.slack_apiToken,
    config.slack_autoReconnect,
    config.slack_autoMark
)

customer_database = require('spatabase-customers') config.mongo_url
jira = new (require './src/Jira') config, customer_database

gitlab = (require 'gitlab')
  url:   config.gitlab_url
  token: config.gitlab_token

############

jiri = new Jiri slack, customer_database, jira, gitlab
