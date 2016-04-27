RSVP = require 'rsvp'
Action = require './Action'
Issue = require '../Issue'
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
        return /\b([A-Z]{3}[0-9]{6})\b/ig

    getRefsDataKey: =>
        return 'refs-' + @channel.id

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) =>
        refs = message.text.match @getTestRegex()

        if !refs.length
            return new RSVP.Promise (resolve, reject) ->
                reject 'No CXM case refs in message'

        @jiri.getActionData @, @getRefsDataKey()
        .then (recentRefs) =>
            if refs.length
                ref = refs[0]
                return null if ref in recentRefs

                @setLoading()
                @loadingTimer = setInterval (=> @setLoading()), 4000

                return @getCxmCase ref
                .catch (err) =>
                    clearInterval @loadingTimer
                    throw err
                .then (response) =>
                    clearInterval @loadingTimer
                    return response
            else
                return null

    getCxmCase: (ref) =>
        return new RSVP.Promise (resolve, reject) =>
            cxm = new Cxm
                url: config.cxm_api_url
                key: config.cxm_api_key
            promise = cxm.case ref
                .catch (err) ->
                    # ignore 404s to avoid noise when matching things that aren't CXM cases
                    if err.errorCode is 404
                        return null
                    else
                        return RSVP.reject err
                .then @dataLoaded
            resolve promise

    dataLoaded: (data) =>
        return new RSVP.Promise (resolve, reject) =>
            reject null unless data

            @jiri.storeActionData @, @getRefsDataKey(), data.reference, config.timeBeforeRepeatUnfurl
            .catch (e) -> console.log "Failed to store CXM key #{data.reference} to avoid repeat unfurling"

            @jiri.recordOutcome @, @OUTCOME_RESULTS, issueCount: 1

            if m = data.values.jira_reference?.match /\b([a-z]{3,6}-\d{4,6})\b/i
                data.jiraRef = m[1]

            # if there's a JIRA ref, output the JIRA ticket details
            if data.jiraRef
                promise = @jiri.jira.search("issue = #{data.jiraRef}", fields: IssueOutput.prototype.FIELDS)
                .then (response) =>
                    issueData = response?.issues?[0]
                    # if we couldn't load the JIRA ticket, start again without reference to it
                    unless issueData
                        delete data.values.jira_reference
                        return @dataLoaded data

                    issueData.cxmCase = data
                    issue = new Issue issueData
                    outputter = new IssueOutput issue
                    response = outputter.getSlackMessage()
                    response.channel = @channel.id
                    return response
                resolve promise

            # if no JIRA ref, output the CXM ticket details
            else
                attachments = []

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

                attachments.push attachment

                resolve
                    attachments: JSON.stringify attachments
                    channel: @channel.id

    test: (message) ->
        new RSVP.Promise (resolve) =>
            return resolve false unless message.type is 'message' and message.text? and message.channel?

            return resolve message.text.match @getTestRegex()

module.exports = CxmCaseInfoAction
