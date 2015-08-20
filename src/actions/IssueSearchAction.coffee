RSVP = require 'rsvp'
IssueInfoAction = require './IssueInfoAction'
Issue = require '../Issue'
IssueOutput = require '../IssueOutput'
ClientRepository = require '../ClientRepository'
config = require '../config'
Pattern = require '../Pattern'
async = require 'async'

class IssueSearchAction extends IssueInfoAction

    MAX_RESULTS: 10

    MATCH_NORMAL: 0
    MATCH_MORE: 1

    OUTCOME_LAST_RESULTS: 1
    OUTCOME_TRUNCATED_RESULTS: 2

    # pattern parts
    patternParts:
        find:
            _: 'what( i|\\\')s|find|search|show( us| me)?|display'
        after_find:
            _: 'still|remaining|left|outstanding|all'
        issueType:
            'issue': 'issues?|tickets?|story|stories'
            'bug': 'bugs?'
            'feature': 'features?'
            'release': 'releases?'
            'deployment': 'deployments?'
            'test item': 'test items?'
        status:
            'to do': 'to work on|to do|to fix'
            'test': 'to test|in testing|test'
            'merge': 'to merge|awaiting merge'
            'webdev': 'web ?dev|for web ?dev|web ?dev to[ \\-]?do'
            'ux': 'ux|needing ux|for ux|ux to[ \\-]?do'
            'to review': '(?:ready )?(to|for|awaiting|needing) review'
            'release': '(?:ready )?(to|for) release|releaseable'
            'in progress': 'open|in progress|being worked on|underway'
        client:
            _: 'for ([a-z0-9\\-\'.: ]+|"[^"]+")'
        search:
            _: '(?:containing|like|matching|with|about) +(?:[“"]([^"]+)[”"]|([^" ]+)(?= |$)) *'

    searchDescription: []

    getType: ->
        return 'IssueSearchAction'

    describe: ->
        return 'find Jira tickets for you, e.g. “Jiri, show me bugs in progress for warrington”'

    test: (message) =>
        return false unless message.type is 'message' and message.text? and message.channel?

        @lastOutcome = @jiri.getLastOutcome @
        if @lastOutcome?.outcome is @OUTCOME_TRUNCATED_RESULTS and message.text.match @getMoreRegex()
            # if Jiri was the last user to speak, assume 'more' is talking to him
            if message.channel.latest.user is @jiri.slack.self.id
                @matched = @MATCH_MORE
                return true
            # otherwise require mention of his name
            pattern = @jiri.createPattern "(?=.*\\bjiri\\b).*more", @morePattern.parts
            if message.text.match pattern.getRegex()
                @matched = @MATCH_MORE
                return true

        if message.text.match @getTestRegex()
            @matched = @MATCH_NORMAL
            return true

    getTestRegex: =>
        unless @pattern
            @pattern = @jiri.createPattern '^jiri (find after_find?)? (\\d+|(?:the )?latest|one)? ?(issueType ?|status ?|client ?|search ?)+\\??$', @patternParts
        return @pattern.getRegex()

    getMoreRegex: =>
        unless @morePattern
            @morePattern = @jiri.createPattern "^jiri?more",
                    more: "(?:(?:show|find|display|give me|gimme|let's have)\\s+)?(?:(\\d+)\\s+)?(?:more|moar|m04r)(?:\\s+(?:please|now))?",
                    true
        return @morePattern.getRegex()

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) =>
        try
            switch @matched
                when @MATCH_NORMAL
                    return new RSVP.Promise (resolve, reject) =>

                        matches = message.text.match @getTestRegex()
                        if matches[2]
                            if matches[2].match /^\d+$/
                                @MAX_RESULTS = parseInt matches[2]
                            else
                                @MAX_RESULTS = 1

                        async.parallel([
                            (callback) =>
                                pattern = @jiri.createPattern "\\bclient\\b", @patternParts, true
                                matches = message.text.match pattern.getRegex()
                                clientRepository = new ClientRepository @jiri
                                if matches?
                                    client = matches[1]
                                    @setLoading()

                                    clientRepository.find client
                                        .then (client) =>
                                            if !client
                                                callback "Client not found for #{client}"

                                            clientName = client.name.replace /'/g, "\\'"
                                            callback null, "'Reporting Customers' = '#{clientName}'"

                                        .catch (error) =>
                                            callback "Couldn't find client #{client}"
                                else
                                    # ignore the blacklist of channels
                                    if message.channel.name in config.slack_nonCustomerChannels.split(/ /)
                                        callback null, null
                                        return

                                    @setLoading()
                                    clientRepository.find message.channel.name
                                        .then (client) =>
                                            clientName = client.name.replace /'/g, "\\'"
                                            callback null, if client then "'Reporting Customers' = '#{clientName}'" else null
                                        .catch (error) =>
                                            callback null

                            (callback) =>
                                pattern = @jiri.createPattern "\\bissueType\\b", @patternParts, true
                                matches = message.text.match pattern.getRegex()
                                if matches? and matches[0] != 'issue'
                                    for own key, value of @patternParts.issueType
                                        continue if key is 'issue'
                                        if matches[0].match new RegExp "(#{value})", 'i'
                                            return callback null, "issuetype = #{key}"

                                callback null, null

                            (callback) =>
                                pattern = @jiri.createPattern "\\bstatus\\b", @patternParts, true
                                matches = message.text.match pattern.getRegex()
                                if matches?
                                    status = null
                                    for own key, value of @patternParts.status when matches[0].match new RegExp "(#{value})", 'i'
                                        switch key
                                            when 'in progress'
                                                status = config.jira_status_inProgress
                                            when 'test'
                                                status = config.jira_status_toTest
                                            when 'webdev'
                                                status = config.jira_status_webdevToDo
                                            when 'ux'
                                                status = config.jira_status_uxToDo
                                            when 'merge'
                                                status = config.jira_status_awaitingMerge
                                            when 'to review'
                                                status = config.jira_status_awaitingReview
                                            when 'release'
                                                status = config.jira_status_readyToRelease

                                        if status?
                                            if typeof status is 'string'
                                                status = "'#{status}'"
                                            else if status.length
                                                status = ("'#{s}'" for s in status)
                                                status = status.join ', '
                                            return callback null, "status IN (#{status})"

                                callback null, null

                            (callback) =>
                                pattern = @jiri.createPattern "\\bsearch\\b", @patternParts, true
                                matches = message.text.match pattern.getRegex()
                                if matches?
                                    if matches[0].match new RegExp "(#{@patternParts.search._})", 'i'
                                        term = matches[1] || matches[2]
                                        return callback null, "text ~ '#{term}'"

                                callback null, null

                            ],
                            (error, queryBits) =>
                                reject error if error

                                query = queryBits.filter((n) -> n?).join(' AND ') +
                                        ' ORDER BY createdDate DESC'

                                message.jiri_jira_query = query
                                message.jiri_jira_startAt = 0
                                message.jiri_jira_limit = @MAX_RESULTS

                                @setLoading()
                                resolve @getJiraIssues query, {maxResults: @MAX_RESULTS + 1}, message

                        )
                when @MATCH_MORE
                    return new RSVP.Promise (resolve, reject) =>
                        match = message.text.match @getMoreRegex()
                        if match[5]?.match /^\d+$/
                            @MAX_RESULTS = parseInt match[5]
                        else
                            @MAX_RESULTS = @lastOutcome.data.limit

                        message.jiri_jira_query = @lastOutcome.data.query
                        message.jiri_jira_startAt = @lastOutcome.data.startAt + @lastOutcome.data.limit
                        message.jiri_jira_limit = @MAX_RESULTS

                        resolve @getJiraIssues @lastOutcome.data.query, {
                                maxResults: message.jiri_jira_limit + 1,
                                startAt: message.jiri_jira_startAt
                            },
                            message
        catch
            console.log "Error building query"

    issuesLoaded: (result, message) =>

        moreAvailable = false

        if result.issues.length > @MAX_RESULTS
            moreAvailable = true
            result.issues = result.issues.slice(0,@MAX_RESULTS)

        count = result.issues.length

        response = super result, message

        if count is 0
            response.text = "I'm afraid I couldn't find any. This is the query I tried: \n```\n#{message.jiri_jira_query}\n```"
        else if message.jiri_jira_startAt > 0
            startAt = message.jiri_jira_startAt
            if count is 1
                response.text = "Here is result #{startAt+1}. "
            else
                response.text = "Here are results #{startAt+1}–#{startAt + count}. "
        else if count is 1
            response.text = "Here it is. "
        else if moreAvailable
            response.text = "Here are the first #{count} I found. "
        else
            response.text = "Here you go — I found #{count}. "

        # show query
        # response.text += "\n```\n#{message.jiri_jira_query}\n```"

        if moreAvailable
            strings = [
                "Just ask if you want more.",
                "I've got more if you want them.",
                "There are more available.",
            ]
            if count is 1
                strings.push "There are more where that came from."
            else
                strings.push "There are more where they came from."

            response.text += strings[Math.floor(Math.random() * strings.length)]

            outcome = @OUTCOME_TRUNCATED_RESULTS
        else
            if @matched is @MATCH_MORE
                strings = [
                    "That's it.",
                    "That's your lot.",
                    "That's all of them.",
                    "There aren't any more.",
                ]
                response.text += strings[Math.floor(Math.random() * strings.length)]

            outcome = @OUTCOME_LAST_RESULTS

        @jiri.recordOutcome @, outcome, {
            query: message.jiri_jira_query
            startAt: message.jiri_jira_startAt
            limit: message.jiri_jira_limit
        }

        response

    getNoneFoundMessage: (message) ->
        return "Sorry #{message.user.profile.first_name}, I couldn't find any #{message.jiri_jira_query}"


module.exports = IssueSearchAction
