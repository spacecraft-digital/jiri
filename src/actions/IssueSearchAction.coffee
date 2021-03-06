IssueInfoAction = require './IssueInfoAction'
config = require '../../config'
Pattern = require '../Pattern'
async = require 'async'
escape_quotes = require 'escape-quotes'

class IssueSearchAction extends IssueInfoAction

    MAX_RESULTS: 10

    MATCH_NORMAL: 0
    MATCH_MORE: 1

    OUTCOME_LAST_RESULTS: 1
    OUTCOME_TRUNCATED_RESULTS: 2

    # pattern parts
    patternParts:
        find:
            _: 'what( is|\\\'s| are)( the)?|find|search|get|show( us| me)?|display'
        after_find:
            _: 'still|remaining|left|outstanding|all'
        issueType:
            'issue': 'issues?|tickets?|story|stories'
            'bug': 'bugs?'
            'feature': 'features?'
            'release': 'releases?'
            'deployment': 'deployments?'
            'test item': 'test items?'
            'epic': 'epics?'
        status:
            'to do': 'to work on|to do|to fix'
            'test': 'to test|in testing|test'
            'merge': 'to merge|awaiting merge'
            'webdev': 'web ?dev|for web ?dev|web ?dev to[ \\-]?do'
            'ux': 'ux|needing ux|for ux|ux to[ \\-]?do'
            'to review': '(?:ready )?(to|for|awaiting|needing) review'
            'release': '(?:ready )?(to|for) release|releaseable'
            'in progress': 'open|in progress|being worked on|underway'
        _search:
            _: '(?:containing|like|matching|with|about) +(?:[“"]([^"]+)[”"]|([^" ]+)(?= |$)) *'

    searchDescription: []

    getType: ->
        return 'IssueSearchAction'

    describe: ->
        return 'find Jira tickets for you, e.g. “Jiri, show me bugs in progress for warrington”'

    test: (message) ->
        new Promise (resolve) =>
            return resolve false unless message.type is 'message' and message.text? and message.channel?

            resolve @jiri.getLastOutcome @
        .then (lastOutcome) =>
            @lastOutcome = lastOutcome
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

            return @getTestRegex().then (regex) =>
                if message.text.match regex
                    @matched = @MATCH_NORMAL
                    return true
                return false

    getTestRegex: =>
        new Promise (resolve, reject) =>
            if @pattern
                return resolve @pattern.getRegex()
            else
                return @customer_database.model('Customer').getAllNameRegexString()
                .then (customerRegex) =>
                    @pattern = @jiri.createPattern "^jiri (find after_find?)? (\\d+|(?:the )?latest|one)? ?(issueType ?|status ?|for #{customerRegex} ?|_search ?)+\\??$", @patternParts
                    return resolve @pattern.getRegex()

    getMoreRegex: =>
        unless @morePattern
            @morePattern = @jiri.createPattern "^jiri?more",
                    more: "(?:(?:show|find|display|give me|gimme|let's have)\\s+)?(?:(\\d+)\\s+)?(?:more|moar|m04r)(?:\\s+(?:please|now))?",
                    true
        return @morePattern.getRegex()

    ####
    # @param query (string) the user input that we've parsed as a customer name
    # @param callback (function) the async callback to progress. Parameters are (string error, string JQL partial query)
    # @param resolve (function) the overall respondTo promise resolution callback — to exit the whole process if needed
    _curryGetJiraMappingIdForCustomer: (query, callback, loadCustomerNames = true) ->
        (customer) =>
            return new Promise (resolve, reject) =>
                return callback "Customer not found for #{query}" unless customer

                Customer = @customer_database.model 'Customer'
                jiraCustomerName = customer.getProject()?._mappingId_jira

                if !jiraCustomerName and loadCustomerNames
                    @jiri.sendResponse text: "Syncing customers with Jira, one moment please…"
                    return @jiri.jira.loadReportingCustomerValues()
                            .then =>
                                console.log "try again…"
                                Customer.findOneByName customer.name
                                    .then @_curryGetJiraMappingIdForCustomer(query, callback, false)
                            .catch (error) ->
                                reject error

                if jiraCustomerName
                    callback null, "'Reporting Customers' = '#{escape_quotes jiraCustomerName}'"
                else
                    resolve text: "I don't know what #{customer.name} is known as in Jira.
                                   Please `set #{customer.name}'s _mappingId_jira`"


    # Returns a promise that will resolve to a response if successful
    respondTo: (message) =>
        return new Promise (resolve, reject) =>
            if @matched is @MATCH_NORMAL
                @getTestRegex().then (regex) =>
                    matches = message.text.match regex

                    if matches[2]
                        if matches[2].match /^\d+$/
                            @MAX_RESULTS = parseInt matches[2]
                        else
                            @MAX_RESULTS = 10

                    Customer = @customer_database.model('Customer')
                    async.parallel([
                        (callback) =>
                            Customer.getAllNameRegexString()
                            .then (customerRegex) =>
                                pattern = @jiri.createPattern "\\b#{customerRegex}\\b", @patternParts, true
                                matches = message.text.match pattern.getRegex()

                                if matches
                                    customerName = matches[1]
                                    promise = Customer.findOneByName matches[1]
                                # use channel name, is not in the blacklist of channels
                                else if message.channel.name not in config.slack_nonCustomerChannels.split(/ /)
                                    customerName = message.channel.name
                                    promise = Customer.findOne(slackChannel: new RegExp("^#{message.channel.name}$",'i'))
                                else
                                    return callback null, null

                                promise.then @_curryGetJiraMappingIdForCustomer(message.channel.name, callback)
                                    .catch (error) => callback null

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
                                            status = @jiri.jira.getStatusNames 'inProgress'
                                        when 'test'
                                            status = @jiri.jira.getStatusNames 'toTest'
                                        when 'webdev'
                                            status = @jiri.jira.getStatusNames 'webdevToDo'
                                        when 'ux'
                                            status = @jiri.jira.getStatusNames 'uxToDo'
                                        when 'merge'
                                            status = @jiri.jira.getStatusNames 'awaitingMerge'
                                        when 'to review'
                                            status = @jiri.jira.getStatusNames 'awaitingReview'
                                        when 'release'
                                            status = @jiri.jira.getStatusNames 'readyToRelease'

                                    if status?
                                        status = ("'#{s}'" for s in status).join ', '
                                        return callback null, "status IN (#{status})"

                            callback null, null

                        (callback) =>
                            pattern = @jiri.createPattern "\\b_search\\b", @patternParts, true
                            matches = message.text.match pattern.getRegex()
                            if matches and matches[0].match new RegExp "(#{@patternParts._search._})", 'i'
                                term = matches[1] || matches[2]
                                return callback null, "text ~ '#{term}'"

                            callback null, null

                        ],
                        (error, queryBits) =>
                            reject error if error

                            query = queryBits.filter((n) -> n?).join(' AND ') +
                                    ' ORDER BY createdDate DESC'

                            @jira_query = query
                            @jira_startAt = 0
                            @jira_limit = @MAX_RESULTS

                            resolve @getJiraIssues query, {maxResults: @MAX_RESULTS + 1}, message
                        )

            else if @matched is @MATCH_MORE
                match = message.text.match @getMoreRegex()
                if match[2]?.match /^\d+$/
                    @MAX_RESULTS = parseInt match[2]
                else
                    @MAX_RESULTS = @lastOutcome.data.limit

                @jira_query = @lastOutcome.data.query
                @jira_startAt = @lastOutcome.data.startAt + @lastOutcome.data.limit
                @jira_limit = @MAX_RESULTS

                resolve @getJiraIssues @lastOutcome.data.query, {
                        maxResults: @jira_limit + 1,
                        startAt: @jira_startAt
                    },
                    message

            else
                reject new Error "Unknown match type"

    issuesLoaded: (issues) =>

        moreAvailable = false

        if issues.length > @MAX_RESULTS
            moreAvailable = true
            issues = issues.slice(0,@MAX_RESULTS)

        count = issues.length

        if count is 0
            return text: "I'm afraid I couldn't find any. This is the query I tried: \n```\n#{@jira_query}\n```"

        response = super issues

        return unless response

        if @jira_startAt > 0
            startAt = @jira_startAt
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
        # response.text += "\n```\n#{@jira_query}\n```"

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
            query: @jira_query
            startAt: @jira_startAt
            limit: @jira_limit
        }

        response


module.exports = IssueSearchAction
