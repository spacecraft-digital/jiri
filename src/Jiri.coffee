config = require './../config'
ActionData = require './ActionData'
Pattern = require './Pattern'
Calendar = require './Calendar'
Cron = require './Cron'

class Jiri

    actions: [
        # require './actions/IssueStatusAction'
        require './actions/FindIssueForSupportTicketAction'
        require './actions/IssueSearchAction'
        require './actions/HelpAction'
        require './actions/ReceiveJiraWebhooksAction'
        require './actions/IssueInfoAction'
        require './actions/CustomerListAction'
        require './actions/CustomerInfoAction'
        require './actions/CustomerSetInfoAction'
        require './actions/GeneralChatAction'
        require './actions/UnknownAction'
    ]

    matchingActions: 0

    constructor: (@slack, @jira, @db) ->
        @debugMode = '--debug' in process.argv

        @slack.on 'open', @onSlackOpen
        @slack.on 'message', @onSlackMessage
        @slack.on 'error', @onSlackError

        @channelState = {}
        @actionData = {}

        @slack.login()

        console.log 'Awakening the Jiri…'

        # Create a cron instance to which we can register callbacks
        @cron = new Cron

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
        message.text = message.text.replace /\s*\bplease\b/, ''

        message

    actOnMessage: (message) =>
        if message.subtype is 'message_changed'
            # if we store messages that come in, by their ts, we could cancel and restart those requests
            # channel: 'D064EK61Y',
            # event_ts: '1439907605.267252',
            # ts: '1439907605.000630'
            return

        if !message.text
            return

        message = @normaliseMessage message

        @matchingActions = 0

        # allow each Action to decide if they want to respond to the message
        for actionClass in @actions
            action = new actionClass @, message.channel
            try
                if action.test message
                    @matchingActions++
                    try
                        promise = action.respondTo(message)
                        if promise?.then
                            promise.then @sendResponse
                            promise.catch (error) =>
                                @actionError error,action
                    catch e
                        console.error "Error running #{action.getType()}: #{e}"

                    break unless action.allowOtherActions()
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

        validData

    sendResponse: (response) =>
        @slack.postMessage response if response

    actionError: (error, action) =>
        if action
            console.error "Action error in #{action.name}"
            console.log error.stack
        else
            console.error error

        @slack.postMessage
            channel: action.channel.id
            text: "Uh oh, something went a bit wrong: _#{error}_"

    # pull People HR calendar feed, and post who is on Holiday/WFH to Slack
    postHolidaysCalendar: =>
        calendar = new Calendar @, config.peopleCalendarUrl
        calendar.loadPeopleCalendar()

    onSlackOpen: () =>
        console.log "Connected to Slack"

        if @debugMode then console.log """

            ******************** DEBUG MODE **************************
            ** I ain't listening to no one other than #{@slack.getUserByID(config.debugSlackUserId).real_name}
            **********************************************************

            """

        # avoid re-registering cron task on reconnect
        unless @holidaysCronAdded
            @holidaysCronAdded = true
            @cron.at @cron.convertToServerTime('07:30'), @postHolidaysCalendar

    onSlackMessage: (message) =>
        # ignore messages Jiri sends
        return if message.user is @slack.self.id

        return if message.userName = '@slackbot' and message.text?.match /^You have been removed/

        # for development, only respond to Matt Dolan
        return if @debugMode and message.subtype != 'bot_message' and message.user != config.debugSlackUserId

        @actOnMessage message

    onSlackError: (error) ->
        console.error "Slack Error: #{error}"


module.exports = Jiri
