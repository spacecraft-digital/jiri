Action = require './Action'
IssueOutput = require '../IssueOutput'
config = require '../../config'
Cxm = require 'cxm'
ucfirst = require 'ucfirst'

class CxmCaseInfoAction extends Action

    OUTCOME_NO_RESULTS: 0
    OUTCOME_RESULTS: 1
    OUTCOME_TRUNCATED_RESULTS: 2

    getType: ->
        return 'CxmCaseInfoAction'

    describe: ->
        return 'give you info about CXM cases that people mention'

    # if one of these matches, this Action will be run
    getTestRegex: ->
        return /\b(SUP[0-9]{6})\b/ig

    getRefsDataKey: =>
        return 'refs-' + @channel.id

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) =>
        m = message.text.match @getTestRegex()
        [ref] = m
        @getCxmCase ref

    getCxmCase: (ref) =>
        cxm = new Cxm
            url: config.cxm_api_url
            key: config.cxm_api_key
        cxm.case ref
        .catch (err) ->
            # ignore 404s to avoid noise when matching things that aren't CXM cases
            if err.errorCode is 404
                return null
            else
                throw err
        .then @dataLoaded

    dataLoaded: (data) =>
        return null unless data

        @jiri.storeActionData @, @getRefsDataKey(), data.reference, config.timeBeforeRepeatUnfurl
        .catch (e) -> console.log "Failed to store CXM key #{data.reference} to avoid repeat unfurling"

        @jiri.recordOutcome @, @OUTCOME_RESULTS, issueCount: 1

        if m = data.values.jira_reference?.match /\b([a-z]{3,6}-\d{4,6})\b/i
            data.jiraRef = m[1]

        # if there's a JIRA ref, output the JIRA ticket details
        if data.jiraRef
            @jiri.jira.getIssue(data.jiraRef).then (issue) =>
                # if we couldn't load the JIRA ticket, start again without reference to it
                unless issue?
                    delete data.values.jira_reference
                    return @dataLoaded data

                issue.setCxmCaseData data.reference, config.cxm_caseUrl.replace(/#\{reference\}/i, data.reference)
                return new IssueOutput(@jiri.jira, issue).getSlackMessage()

        # if no JIRA ref, output the CXM ticket details
        else
            text = ''
            text += "#{ucfirst data.values.type} " if data.values.type
            text += "`#{data.status?.title}` "

            attachment =
                mrkdwn_in: ["text", "pretext"]
                fallback: "[#{data.reference}] #{data.values.subject}"
                author_icon: 'https://emoji.slack-edge.com/T025466D2/q/820184910a1104c4.png'
                author_name: "#{data.reference} #{data.values.subject}"
                author_link: config.cxm_caseUrl.replace /#\{([a-z0-9_]+)\}/, (m, key) => return data[key]
                text: text

            attachments: JSON.stringify [attachment]

    test: (message) ->
        return Promise.resolve false unless message.type is 'message' and message.text? and message.channel?

        if m = message.text.match @getTestRegex()
            [ref] = m
            @jiri.getActionData(@, @getRefsDataKey()).then (recentRefs) =>
                if recentRefs.length is 0 or ref not in recentRefs
                    return true
                else
                    return 'ignore'
        else
            Promise.resolve false

module.exports = CxmCaseInfoAction
