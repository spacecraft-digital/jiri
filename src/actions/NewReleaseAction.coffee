Action = require './Action'
config = require '../../config'
IssueOutput = require '../IssueOutput'
assert = require 'assert'

class NewReleaseAction extends Action

    regex:
        create: '^(?:jiri )?(?:create|make|new) (?:a )?(?:new )?release(?: for (__customer__))?$'

    getType: ->
        return 'NewReleaseAction'

    describe: ->
        return 'create a new customer release'

    # if one of these matches, this Action will be run
    getPatternRegex: (name = null) ->
        @customer_database.model('Customer').getAllNameRegexString()
        .then (customerRegex) =>
            unless @patternRegexes
                @patternRegexes = {}
                for own key, regex of @regex
                    regex = regex.replace '__customer__', customerRegex
                    @patternRegexes[key] = @jiri.createPattern(regex).getRegex()
            return if name then @patternRegexes[name] else @patternRegexes

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        # defined here to set the scope
        customerName = null

        @getPatternRegex()
        .then (regexes) =>
            # remove question mark
            message.text = message.text.replace /\?+$/, ''

            Customer = @customer_database.model 'Customer'

            if m = message.text.match regexes.create
                customerName = m[1]
                if customerName
                    Customer.findOneByName(customerName)
                else if message.channelCustomerId
                    Customer.findOne _id: message.channelCustomerId
                else
                    assert false, "Can you specify which customer / project you mean?"
        .then (customer) =>
            throw new Error "Unable to find customer #{customerName}" unless customer
            Promise.all [
                customer
                @jiri.jira.createNewReleaseTicket customer, customer.getProject()
            ]
        .then ([customer, release]) =>
            outputter = new IssueOutput @jiri.jira, release
            response = outputter.getSlackMessage()
            response.text = "Voila. One new release for #{customer.getName()}:"
            response
        .catch (e) =>
            # handle assertion errors as okay — just return message
            if e?.name is 'AssertionError'
                return e.message
            # other errors get rethrown
            else
                throw e

    test: (message) ->
        @getPatternRegex()
        .then (regexes) ->
            for own name,regex of regexes
                if message.text.match(regex)
                    return true
            return false

module.exports = NewReleaseAction
