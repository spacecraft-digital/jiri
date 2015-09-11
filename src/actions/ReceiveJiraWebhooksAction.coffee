Action = require './Action'
config = require '../../config'
RSVP = require 'rsvp'
IssueOutput = require '../IssueOutput'

class ReceiveJiraWebhooksAction extends Action

    getType: ->
        return 'ReceiveJiraWebhooksAction'

    describe: ->
        # we don't want to publicise this one
        return

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        return message.subtype is 'bot_message' and
               message.channel.is_im and
               message.channel.name is 'slackbot' and
               message.username is 'Jira'

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        data = @parseData message.text.replace /^@jiri\s+/, ''

        switch data.action
            when "createCodeReview"
                user = @jiri.slack.findUserByEmail data.userEmail
                userName = if user then "@#{user.name}" else data.userEmail.replace(/@.+$/, '').replace(/\./,' ')

                return new RSVP.Promise (resolve, reject) ->
                    response =
                        text: "<!channel> Review for #{userName} please: "
                        channel: 'zapier-test'
                    response.attachments = JSON.stringify [
                        author_name: "#{data.key} #{data.summary}"
                        fallback: "[#{data.key}] #{data.summary}"
                        text: "for #{data.reportingCustomer.value}"
                    ]
                    resolve response

        # console.log "Message from Jira:\n\n#{message.text}"
        #

    parseData: (messageText) ->
        data = {}
        multiLineMarker = false
        multiLineKey = null

        messageText.replace /^(?:([a-z0-9_\-]+): )?(.+)$/img, (m, key, value) ->
            # end of multi line
            if multiLineMarker and value is multiLineMarker
                multiLineMarker = null

            # start of multi line
            else if value.match /^(<|&lt;){3}([a-z]+)/i
                multiLineMarker = value.replace /^(<|&lt;){3}/, ''
                multiLineKey = key
                data[key] = {}
                return

            # mid-multi line
            else if multiLineMarker
                data[multiLineKey][key] = value

            # single line
            else if key
                data[key] = value

        return data

module.exports = ReceiveJiraWebhooksAction
