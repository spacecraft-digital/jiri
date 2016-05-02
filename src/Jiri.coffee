config = require './../config'
Pattern = require './Pattern'
Calendar = require './Calendar'
Cron = require './Cron'
async = require 'async'
mc_array = require 'mc-array'
colors = require 'colors'
joinn = require 'joinn'
EventEmitter = require 'events'

class Jiri extends EventEmitter

    constructor: (@slack, @customer_database, @jira, @gitlab, @cache) ->
        @cacheArrays = {}
        @debugMode = '--debug' in process.argv

        @slack.on 'open', @onSlackOpen
        @slack.on 'message', @onSlackMessage
        @slack.on 'error', @onSlackError

        @slack.login()

        # Create a cron instance to which we can register callbacks
        @cron = new Cron

        @loadActions()

        console.log colors.bgWhite.grey "Hello, my name's Jiri."

    loadActions: ->
        @actions = []
        actions = [
            'IgnoreMeAction'
            'DependenciesAction'
            'ReleaseReadAction'
            'ReleaseWriteAction'
            'IssueSearchAction'
            'HelpAction'
            'ReceiveJiraWebhooksAction'
            'ServerVersionsAction'
            'ServerLogAction'
            'IssueInfoAction'
            'CxmCaseInfoAction'
            'CustomerListAction'
            'CustomerInfoAction'
            'CustomerSetInfoAction'
            'GeneralChatAction'
            'UnknownAction'
        ]
        for action in actions
            actionPath = "./actions/#{action}"
            delete require.cache[require.resolve actionPath] if @debugMode
            @actions.push require actionPath

    createPattern: (metaPattern, parts, subpartMatches = false) ->
        pattern = new Pattern metaPattern, parts, subpartMatches
        pattern.setSlack @slack
        pattern

    normaliseMessage: (message) ->
        if typeof message.channel is 'string'
            message.channel = @slack.getChannelGroupOrDMByID message.channel
            message.channelName = if message.channel?.is_channel then '#' else ''
            message.channelName = message.channelName + if message.channel then message.channel.name else 'UNKNOWN_CHANNEL'

        if typeof message.user is 'string'
            message.user = @slack.getUserByID message.user
            message.userName = if message.user?.name? then "@#{message.user.name}" else "UNKNOWN_USER"

        # to simplify matching, if Jiri is addresses via a DM, we'll ensure "@jiri " is prefixed, so we
        # can use the same patterns to match there as in other channels
        if message.channel.is_im and not message.text.match @createPattern('jiri').getRegex()
            message.text = '@jiri ' + message.text

        # remove politeness
        message.text = message.text.replace /\s*\bplease\b/, ''

        message.text = message.text.trim()

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

        # in debug mode, reload action scripts each time — avoids having to restart Jiri for changes
        @loadActions() if @debugMode

        loadingTimer = null
        # allow each Action to decide if they want to respond to the message
        async.detectSeries @actions, (actionClass, done) =>
            action = new actionClass @, @customer_database, message.channel
            action.test message
            .catch (e) ->
                console.error "Error testing #{action.getType()}"
                console.log if e.stack then e.stack else e
                return false
            .then (match) =>
                return done false unless match
                done true
                loadingTimer = @slack.setTyping message.channel.id
                action.respondTo message
            .then (reply) =>
                return null unless reply
                clearInterval loadingTimer
                if typeof reply is 'string'
                    reply = text: reply
                throw new Error 'Action response must be a string or an object' unless typeof reply is 'object'
                reply.channel = message.channel.id
                @sendResponse reply
            .catch (e) =>
                clearInterval loadingTimer
                @actionError e, action, message

        , (actionClass) ->
            return unless actionClass
            d = new Date
            console.log "[#{d.toISOString()}] #{message.userName}
                         in #{if message.channel.is_im then "DM" else message.channel.name}:
                         “#{message.text}” -> #{actionClass.name}"

    channelStateCacheKey: (channel) ->
        "channel-state:#{channel.id}"

    memcachedError: (err) =>
        if err?.type is 'CONNECTION_ERROR'
            # emit an event so the app can reconnect to memcached
            @emit 'memcached:connection_error'

    # for storing state
    # The Action object must have a channel ID set
    # The outcome is a string which is meaningful to the Action
    # The data parameter is an object to be used however the Action wants
    # @param action     Action object OR action type string
    # @param outcome    integer     Specifies the type of outcome, meaningful to the Action class
    # @param data       object      Any state data required
    # @param channel    object      Optional Channel object. Only required if action is a string
    recordOutcome: (action, outcome, data = {}, channel = null) =>
        actionType = action.getType() unless typeof action is 'string'
        channel = action.channel if channel is null and typeof action is 'object'

        o = JSON.stringify {
            action: actionType
            outcome: outcome
            data: data
        }
        @cache.set @channelStateCacheKey(channel), o, (err, response) =>
            @memcachedError err if err

    # Action action — Action object
    # Returns an object with outcome and data
    getLastOutcome: (action) ->
        return new Promise (resolve, reject) =>
            cacheKey = @channelStateCacheKey action.channel
            @cache.get cacheKey, (err, response) =>
                if err
                    @memcachedError err
                    return resolve null
                state = JSON.parse response[cacheKey]
                if state? and state.action is action.getType()
                    return resolve
                        outcome: state.outcome
                        data: state.data
                else
                    return resolve null

    getCacheArray: (key) ->
        unless @cacheArrays[key]
            @cacheArrays[key] = new mc_array @cache, "action-data:#{key}"
        @cacheArrays[key]

    actionDataCacheKey: (action, key) ->
        action = action.getType() unless action is 'string'
        return action + ':' + key

    getTimeFromNow: (s = 0) ->
        Math.floor(Date.now()/1000) + s

    storeActionData: (action, key, value, ttl = 60) =>
        @getCacheArray(@actionDataCacheKey action, key).add
            value: value
            expire: @getTimeFromNow ttl
        .catch @memcachedError

    getActionData: (action, key) =>
        cacheArray = @getCacheArray(@actionDataCacheKey action, key)
        cacheArray.get()
        .then (values) =>
            now = @getTimeFromNow()
            validData = []
            for o in values
                # remove expired
                if o.expire < now
                    cacheArray.remove o
                else
                    validData.push o.value
            validData
        .catch @memcachedError

    sendResponse: (response) =>
        return unless response
        console.log "Response to #{response.channel}: #{response.text}" if @debugMode and '--show-response' in process.argv
        response.text = ":sparkles: " + (response.text||'') if @debugMode
        @slack.postMessage response

    actionError: (error, action, message) =>
        console.log "Action error in #{action.getType()}:", error.stack||error
        if error.stack
            stackLines = error.stack.split "\n"

        @notifyAdmins """
            #{action.getType()} went a bit wrong in #{action.channel.name}, responding to
            > #{message.text.replace("\n","\n> ")}
            ```
            #{stackLines.slice(0,1).join("\n")}
            ```
        """

        return null

    # pull People HR calendar feed, and post who is on Holiday/WFH to Slack
    postHolidaysCalendar: =>
        calendar = new Calendar @, config.peopleCalendarUrl
        calendar.loadPeopleCalendar()

    notifyAdmins: (message) =>
        for channel in config.slack_processAlerts||[]
            @slack.postMessage
                text: message
                channel: channel

    onTerminate: (signal, err = '') =>
        @notifyAdmins "I've been told to quit, so I'm off for now :wave:"
        setTimeout ->
            console.log "Terminated by SIGTERM"
            process.exit()
        , 1000

    onSlackOpen: () =>
        console.log colors.yellow "Connected to Slack"

        if @debugMode and config.slack_userId_whitelist
            names = (@slack.getUserByID(u)?.real_name for u in config.slack_userId_whitelist)
            console.log colors.cyan "(Ignoring everyone except #{joinn names})"

        @notifyAdmins if @debugMode then "Debug instance run by `#{process.env.LOGNAME}`" else "I'm back!"

        # avoid re-registering cron task on reconnect
        unless @holidaysCronAdded
            @holidaysCronAdded = true
            @cron.at @cron.convertToServerTime('07:30'), @postHolidaysCalendar

        unless @deathArrangementsMade
            @deathArrangementsMade = true
            process.on 'SIGTERM', @onTerminate

    onSlackMessage: (message) =>
        # ignore messages Jiri sends
        return if message.user is @slack.self.id

        return if message.userName is '@slackbot' and message.text?.match /^You have been removed/

        # Ignore some bots
        config.slack_botsToIgnore = config.slack_botsToIgnore.split(/[ ,;]+/) if typeof config.slack_botsToIgnore is 'string'
        return if message.subtype is 'bot_message' and message.username in config.slack_botsToIgnore

        # for development, only respond to Matt Dolan
        if @debugMode
            if message.user in config.slack_userId_whitelist or (message.subtype is 'bot_message' and message.username in ['Jiri', 'Slackbot'])
                @actOnMessage message
            return

        @actOnMessage message

    onSlackError: (error) ->
        console.error "Slack Error", error


module.exports = Jiri
