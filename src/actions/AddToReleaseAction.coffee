Action = require './Action'
config = require '../../config'
IssueOutput = require '../IssueOutput'
assert = require 'assert'

class AddToReleaseAction extends Action

    regex:
        add: '^(jiri )?add ([A-Z]{2,5}-[0-9]{2,5}) to (?:(.+) )?release(?: ([\\d.]+))?$'

    getType: ->
        return 'AddToReleaseAction'

    describe: ->
        return 'add a JIRA ticket to a release'

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
        featureTicketPromise = null
        customerName = null
        releaseVersion = null

        @getPatternRegex()
        .then (regexes) =>
            # remove question mark
            message.text = message.text.replace /\?+$/, ''

            mode = null
            Customer = @customer_database.model 'Customer'

            if m = message.text.match regexes.add
                [..., ref, customerName, releaseVersion] = m

                releaseVersion = releaseVersion || 'next'

                # we'll start to get the ticket now to save time later
                featureTicketPromise = @jiri.jira.getIssue ref

                if customerName
                    Customer.findOneByName customerName
                else if message.channelCustomerId
                    Customer.findOne _id: message.channelCustomerId
                else
                    assert false, "Can you specify which customer / project you mean?"
        .then (customer) =>
            assert false, "Unable to find customer #{customerName}" unless customer
            Promise.all [
                customer
                @jiri.jira.getReleaseTicket customer.project, releaseVersion
                featureTicketPromise
            ]
        .then ([customer, release, feature]) =>
            unless release
                if releaseVersion is 'next'
                    return @jiri.jira.createNewReleaseTicket customer.project
                    .then (release) ->
                        throw new Error "Failed to create a new release ticket for #{customer.name} #{project.getName(true)}" unless release
                        Promise.all [
                            release.addFeature feature
                            feature
                        ]
                else
                    throw new Error "I couldn't find the appropriate release ticket" unless release
            Promise.all [
                release.addFeature feature
                feature
            ]
        .then ([release, feature]) =>
            text = "`<#{feature.url}|#{feature.summary}>` added to release <#{release.url}|#{release.summary}>"
            new IssueOutput(@jiri.jira, release).getSlackMessage text

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

module.exports = AddToReleaseAction
