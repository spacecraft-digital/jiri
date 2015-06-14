config = require './config'
db = require './db'

class Jiri

    interpretters: [
        require './IssueInfoInterpretter'
    ]

    constructor: (@slack, @jira) ->
        @slack.on 'open', @onSlackOpen
        @slack.on 'message', @onSlackMessage
        @slack.on 'error', @onSlackError

        @slack.login()

        console.log 'Never fear, Jiri is here'

    normaliseMessage: (message) ->
        message.channel = @slack.getChannelGroupOrDMByID message.channel
        message.channelName = if message.channel?.is_channel then '#' else ''
        message.channelName = message.channelName + if message.channel then message.channel.name else 'UNKNOWN_CHANNEL'

        message.user = @slack.getUserByID message.user
        message.userName = if message.user?.name? then "@#{message.user.name}" else "UNKNOWN_USER"

        message

    interpretMessage: (message) ->
        message = @normaliseMessage message

        # allow each Interpretter to decide if they want to respond to the message
        for interpreterClass in @interpretters
            if interpreterClass.prototype.test message
                interpreter = new interpreterClass @
                interpreter.respondTo(message)
                    .then @sendResponse
                    .catch @interpreterError
                break

    sendResponse: (response) =>
        @slack.postMessage response

    interpreterError: (error) =>

    onSlackOpen: () =>
        console.log "Connected to Slack"

    onSlackMessage: (message) =>
        @interpretMessage message

    onSlackError: (error) ->
        console.error "Slack Error: #{error}"


module.exports = Jiri
