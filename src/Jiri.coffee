config = require './config'
ActionData = require './ActionData'
Pattern = require './Pattern'

class Jiri

    actions: [
        # require './actions/IssueStatusAction'
        require './actions/FindIssueForSupportTicketAction'
        require './actions/IssueSearchAction'
        require './actions/IssueInfoAction'
        require './actions/GeneralChatAction'
        require './actions/HelpAction'
        require './actions/UnknownAction'
    ]

    matchingActions: 0

    constructor: (@slack, @jira, @db) ->
        @slack.on 'open', @onSlackOpen
        @slack.on 'message', @onSlackMessage
        @slack.on 'error', @onSlackError

        @channelState = {}
        @actionData = {}

        @slack.login()

        console.log 'Never fear, Jiri is here'

    createPattern: (metaPattern, parts, subpartMatches = false) ->
        pattern = new Pattern metaPattern, parts, subpartMatches
        pattern.setSlack @slack
        pattern

    normaliseMessage: (message) ->
        message.channel = @slack.getChannelGroupOrDMByID message.channel
        message.channelName = if message.channel?.is_channel then '#' else ''
        message.channelName = message.channelName + if message.channel then message.channel.name else 'UNKNOWN_CHANNEL'

        message.user = @slack.getUserByID message.user
        message.userName = if message.user?.name? then "@#{message.user.name}" else "UNKNOWN_USER"

        # to simplify matching, if Jiri is addresses via a DM, we'll ensure "@jiri " is prefixed, so we
        # can use the same patterns to match there as in other channels
        if message.channel.is_im and not message.text.match @createPattern('jiri').getRegex()
            message.text = '@jiri ' + message.text

        # remove politeness
        if message.text
            message.text = message.text.replace /\s*\bplease\b/, ''

        message

    actOnMessage: (message) =>
        message = @normaliseMessage message

        @matchingActions = 0

        # allow each Action to decide if they want to respond to the message
        for actionClass in @actions
            action = new actionClass @, message.channel
            try
                if action.test message
                    @matchingActions++
                    try
                        action.respondTo(message)
                            .then @sendResponse
                            .catch (error) =>
                                @actionError error,action
                    catch e
                        console.error "Error running #{action.getType()}: #{e}"
                    break
            catch e
                console.error "Error testing #{action.getType()}: #{e}"

    # for storing state
    # The Action object must have a channel ID set
    # The outcome is a string which is meaningful to the Action
    # The data parameter is an object to be used however the Action wants
    recordOutcome: (action, outcome, data = {}) =>
        @channelState[action.channel.id] =
            action: action.getType()
            outcome: outcome
            data: data

    # Action action — Action object
    # Returns an object with outcome and data
    getLastOutcome: (action) =>
        state = @channelState[action.channel.id]
        if state? and state.action is action.getType()
            return {
                outcome: state.outcome
                data: state.data
            }

    storeActionData: (action, key, value, ttl = 60) =>
        a = action.getType()
        unless @actionData[a]
            @actionData[a] = {}
        unless @actionData[a][key]
            @actionData[a][key] = []

        datum = new ActionData key, value, ttl
        @actionData[a][key].push datum

    getActionData: (action, key) =>
        a = action.getType()
        return [] if not @actionData[a] or not @actionData[a][key]

        validData = []
        validData.push datum for datum in @actionData[a][key] when not datum.expired()

        @actionData[a] = validData
        validData

    sendResponse: (response) =>
        @slack.postMessage response if response

    actionError: (error, action) =>
        console.error 'Action error: ' + error
        @slack.postMessage
            channel: action.channel.id
            text: "Uh oh, something went a bit wrong: _#{error}_"

    onSlackOpen: () =>
        console.log "Connected to Slack"

    onSlackMessage: (message) =>
        # ignore messages Jiri sends
        return if message.subtype is 'bot_message' and message.username?.match /Jiri/

        # for development, only respond to Matt Dolan
        return unless message.user is 'U025466D6'

        @actOnMessage message

    onSlackError: (error) ->
        console.error "Slack Error: #{error}"


module.exports = Jiri
