# Send a message to Slack via Web API to allow for attachments and better formatting

querystring = require 'querystring'
https = require 'https'
Slack = require 'slack-client'

config = require './../config'

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
        data.as_user = true

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

        req.on 'error', (error) ->
            console.error error

        req.write post_data
        req.end()

    setTyping: (channelId) ->
        @_send
            type: "typing"
            channel: channelId

    ##
    # Returns a user with the given email address, if found
    #
    # @param string email
    # @return object
    #
    findUserByEmail: (email) ->
        # escape email for regex
        email = email.replace /[-\/\\^$*+?.()|[\]{}]/g, '\\$&'

        # match @jadu.co.uk or @jadu.net
        email = email.replace /@jadu\\\.(net|co\\\.uk)$/, '@jadu\\.(net|co\\.uk)'

        regex = new RegExp "^#{email}$", 'i'

        for own id, user of @users
            if user.profile?.email?.match regex
                return user

    # escape any formatting characters
    escape: (s) ->
        s.replace /`/g, '%60'
         .replace /_/g, '%5F'
         .replace /\*/g, '%2A'

module.exports = JiriSlack
