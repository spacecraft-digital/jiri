RSVP = require 'rsvp'
Action = require './Action'
Issue = require '../Issue'
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
        return /\b(([A-Z]{2,5})-?(?!112\.)[0-9]{2,5}\b)/ig

    constructor: (@jiri, @channel) ->

    getRefsDataKey: =>
        return 'refs-' + @channel.id

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        rawRefs = message.text.match @getTestRegex()

        if !rawRefs.length
            return new RSVP.Promise (resolve, reject) ->
                reject('No Jira refs in message')

        recentRefs = (ref.value for ref in @jiri.getActionData @, @getRefsDataKey())

        # handle references missing a hyphen
        refs = []
        for ref in rawRefs
            [..., x, y] = ref.match(/^([a-z]+)-?(\d+)$/i)
            ref = "#{x}-#{y}".toUpperCase()
            # ignore recently handled refs
            found = recentRef for recentRef in recentRefs when recentRef is ref
            refs.push ref unless found

        if refs.length
            return @getJiraIssues "issue in (#{refs.join(', ')}) ORDER BY issue"
        else
            return new RSVP.Promise (resolve, reject) ->
                resolve()

    getJiraIssues: (query, opts, message) =>
        options =
            maxResults: 10
            fields: IssueOutput.prototype.FIELDS
        for own key, value of opts
            options[key] = value

        loadingTimer = null

        @setLoading()
        loadingTimer = setInterval (=> @setLoading()), 4000

        @jiri.jira.search(query, options)
        .then (result) =>
            clearInterval loadingTimer
            @issuesLoaded result, message
        .catch (error) =>
            clearInterval loadingTimer
            @errorLoadingIssues error

    issuesLoaded: (result, message) =>

        issues = []

        if result?.issues
            for issue in result.issues when issue?
                issues.push new Issue(issue)
                @jiri.storeActionData @, @getRefsDataKey(), issue.key, config.timeBeforeRepeatUnfurl

        @jiri.recordOutcome @, @OUTCOME_RESULTS, 
            issueCount: issues.length

        if issues.length
            outputter = new IssueOutput issues
            response = outputter.getSlackMessage()

            response.channel = @channel.id
            response

    errorLoadingIssues: (error) =>
        console.log error.stack
        # throw an error, unless we've just sniffed the refs
        throw error unless @getType() is 'IssueInfoAction'

    test: (message) ->
        return false unless message.type is 'message' and message.text? and message.channel?

        return true if message.text.match @getTestRegex()

module.exports = IssueInfoAction
