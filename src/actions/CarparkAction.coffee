Action = require './Action'

class CarparkAction extends Action

    getType: ->
        return 'CarparkAction'

    describe: ->
        return 'tells you whose car is blocking you in'

    getCarRegRegex: ->
        /\b([A-Z]{2}[0-9]{2}[A-Z]{3})|([A-Z][0-9]{1,3}[A-Z]{3})|([A-Z]{3}[0-9]{1,3}[A-Z])|([0-9]{1,4}[A-Z]{1,2})|([0-9]{1,3}[A-Z]{1,3})|([A-Z]{1,2}[0-9]{1,4})|([A-Z]{1,3}[0-9]{1,3})/i

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        # remove duplicate refs, so we can know if we receive data for all that we asked for
        @refs.reduce unique
        return @getJiraIssues "issue in (#{@refs.join(', ')}) ORDER BY issue", {}, message

    test: (message) ->
        return Promise.resolve false unless message.type is 'message' and message.text? and message.channel?

        if message.text.match(/\bcar\b/i) and message.test.match(@getCarRegRegex())
            Promise.resolve true

module.exports = CarparkAction
