Action = require './Action'
IssueOutput = require '../IssueOutput'
config = require '../../config'

# To extend this class, you probably just need to override the respondTo method and refRegex property (or the test method for advanced)
class IssueInfoAction extends Action

    OUTCOME_NO_RESULTS: 0
    OUTCOME_RESULTS: 1
    OUTCOME_TRUNCATED_RESULTS: 2

    getType: ->
        return 'IssueInfoAction'

    describe: ->
        return 'give you info about Jira tickets that people mention'

    # if one of these matches, this Action will be run
    getTestRegex: ->
        return /\b(([A-Z]{2,5})-(?!112\.)[0-9]{2,5}\b)/ig

    getRefsDataKey: =>
        return 'refs-' + @channel.id

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        rawRefs = message.text.match @getTestRegex()

        if !rawRefs.length
            return new Promise (resolve, reject) ->
                reject('No Jira refs in message')

        @jiri.getActionData @, @getRefsDataKey()
        .then (recentRefs) =>
            # handle references missing a hyphen
            refs = []
            for ref in rawRefs
                [..., x, y] = ref.match(/^([a-z]+)-?(\d+)$/i)
                ref = "#{x}-#{y}".toUpperCase()
                # ignore recently handled refs
                refs.push ref unless ref in recentRefs

            if refs.length
                return @getJiraIssues "issue in (#{refs.join(', ')}) ORDER BY issue", {}, message
            else
                return new Promise (resolve, reject) ->
                    resolve()

    getJiraIssues: (query, opts, message) =>
        options =
            maxResults: 10
        for own key, value of opts
            options[key] = value

        @jiri.jira.search query, options
        .then @issuesLoaded
        .catch (error) =>
            @errorLoadingIssues error, message

    issuesLoaded: (issues) =>
        @jiri.storeActionData @, @getRefsDataKey(), issue.key, config.timeBeforeRepeatUnfurl for issue in issues

        @jiri.recordOutcome @, @OUTCOME_RESULTS,
            issueCount: issues.length

        if issues.length
            outputter = new IssueOutput issues
            outputter.getSlackMessage()

    errorLoadingIssues: (error, message) =>
        if @getType() is 'IssueInfoAction' and error is 'Problem with the JQL query'
            # if the message was just a ticket ref, respond even if the ticket's not found
            issueOnly = message.text.match @jiri.createPattern('^jiri? ([a-z]{2,5}-[0-9]{2,5}) *$').getRegex()
            return if issueOnly
                text: "#{issueOnly[1].toUpperCase()} doesn't appear to be a valid JIRA reference…"
        else
            console.log 'Error loading issues: ', error
            # throw an error, unless we've just sniffed the refs
            throw error

    test: (message) ->
        new Promise (resolve) =>
            return resolve false unless message.type is 'message' and message.text? and message.channel?

            return resolve message.text.match @getTestRegex()

module.exports = IssueInfoAction
