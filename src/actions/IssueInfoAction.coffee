Action = require './Action'
IssueOutput = require '../IssueOutput'
config = require '../../config'
unique = require 'reduce-unique'
joinn = require 'joinn'
converter = require 'number-to-words'

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
        return /\b(([A-Z]{2,5})-(?!112\.)[0-9]{2,5}\b)!?/ig

    getRefsDataKey: =>
        return 'refs-' + @channel.id

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        # remove duplicate refs, so we can know if we receive data for all that we asked for
        @refs.reduce unique
        return @getJiraIssues "issue in (#{@refs.join(', ')}) ORDER BY issue", {}, message

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
            if issues.length < @refs.length
                notFoundRefs = issues.filter (issue) -> !ref for ref in @refs when ref is issue.key
                if notFoundRefs
                    if issues.length is 1
                        text = "I couldn't find #{joinn notFoundRefs}, but here's #{issues[0].ref}:"
                    else
                        text = "I couldn't find #{joinn notFoundRefs}, but here are the other #{converter.toWords issues.length}:"
            new IssueOutput(@jiri.jira, issues).getSlackMessage text

    errorLoadingIssues: (error, message) =>
        if @getType() is 'IssueInfoAction' and error is 'Problem with the JQL query'
            # if the message was just a ticket ref, respond even if the ticket's not found
            issueOnly = message.text.match @jiri.createPattern('^jiri? ([a-z]{2,5}-[0-9]{2,5}) *$').getRegex()
            return if issueOnly
                text: "#{issueOnly[1].toUpperCase()} doesn't appear to be a valid JIRA reference…"
        else if @getType() is 'IssueInfoAction' and error?.errorMessages?
            text: "JIRA objected: ```#{error.errorMessages.join "\n"}\n```"
        else
            console.log 'Error loading issues'
            # throw an error, unless we've just sniffed the refs
            throw error

    test: (message) =>
        return Promise.resolve false unless message.type is 'message' and message.text? and message.channel?

        @refs = []
        if refs = message.text.match @getTestRegex()
            @jiri.getActionData(@, @getRefsDataKey()).then (recentRefs) =>
                for ref in refs
                    forceRepeat = ref.substr(-1) is '!'
                    ref = ref.toUpperCase().replace /[^\dA-Z\-]/, ''
                    if ref not in @refs and (forceRepeat or ref not in recentRefs)
                        @refs.push ref.replace /!$/, ''

                return @refs.length or 'ignore'
        else
            Promise.resolve false

module.exports = IssueInfoAction
