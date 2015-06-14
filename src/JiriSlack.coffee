# Send a message to Slack via Web API to allow for attachments and better formatting

querystring = require 'querystring'
https = require 'https'
Slack = require 'slack-client'

config = require './config'

# Extends the Slack client app
class JiriSlack extends Slack

  # Sends a reply via the web API to take advantage of links, attachments, etc
  #
  # The data parameter is an object with properties as defined by
  # https://api.slack.com/methods/chat.postMessage
  postMessage: (data) =>

    data.token = config.slack_apiToken
    data.username = config.bot_name
    data.icon_url = config.bot_iconUrl

    post_data = querystring.stringify data

    post_options =
      hostname: 'slack.com'
      port: 443
      path: '/api/chat.postMessage'
      method: 'POST'
      headers:
        'Content-Type': 'application/x-www-form-urlencoded'
        'Content-Length': post_data.length

    req = https.request post_options, (res) ->
      res.setEncoding('utf8');
      res.on 'data', (chunk) ->
          console.log('Response: ' + chunk)

    req.on 'error', (error) ->
      console.error error

    req.write post_data
    req.end()


module.exports = JiriSlack
