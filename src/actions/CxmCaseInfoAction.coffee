RSVP = require 'rsvp'
Action = require './Action'
Issue = require '../Issue'
IssueOutput = require '../IssueOutput'
config = require '../../config'
Cxm = require 'cxm'
truncate = require 'truncate'

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
    respondTo: (message) ->
        refs = message.text.match @getTestRegex()

        if !refs.length
            return new RSVP.Promise (resolve, reject) ->
                reject 'No CXM case refs in message'

        recentRefs = (ref.value for ref in @jiri.getActionData @, @getRefsDataKey())

        if refs.length #and ref not in recentRefs
            return @getCxmCase refs[0]
        else
            return new RSVP.Promise (resolve, reject) ->
                resolve()

    getCxmCase: (ref) =>
        return new Promise (resolve, reject) =>
            cxm = new Cxm
                url: config.cxm_api_url
                key: config.cxm_api_key
            resolve cxm.case(ref).then @dataLoaded

    dataLoaded: (data) =>
        return new Promise (resolve, reject) =>
            resolve null unless data

            @jiri.storeActionData @, @getRefsDataKey(), data.reference, config.timeBeforeRepeatUnfurl

            @jiri.recordOutcome @, @OUTCOME_RESULTS,
                issueCount: 1

            attachments = []

            attachment =
                mrkdwn_in: ["text"]
                fallback: "[#{data.reference}] #{data.values.subject}"
                author_name: "#{data.reference} #{data.values.subject}"
                author_link: "https://jadusupport.q.jadu.net/q/case/#{data.reference}/timeline"
                text: truncate data.values.message, 50

            attachments.push attachment

            resolve
                attachments: JSON.stringify attachments
                channel: @channel.id

    test: (message) ->
        new RSVP.Promise (resolve) =>
            return resolve false unless message.type is 'message' and message.text? and message.channel?

            return resolve message.text.match @getTestRegex()

module.exports = CxmCaseInfoAction
