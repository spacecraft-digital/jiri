Action = require './Action'
config = require '../../config'
ReleaseIssue = require 'jadu-jira/lib/ReleaseIssue'
IssueOutput = require '../IssueOutput'
assert = require 'assert'

class ReleaseReadAction extends Action

    # what's oxford's latest release
    # get oxford's latest release
    # show oxford's latest release
    # show oxford release 1.3
    regex:
        get1: '^(?:jiri )?(?:what(?:[\'’]s| is)|show|find|get) (?:the )?(latest|last|previous|next|\\d.\\d(?:.\\d)?)? ?release(?: for __customer__)?\\??$'
        get2: '^(?:jiri )?(?:what(?:[\'’]s| is)|show|find|get) (?:__customer__(?:[\'’]?s)? )(latest|last|previous|next|[\\d.]+)? ?release\\??$'
        when: '^(?:jiri )?(?:when(?:[\'’]s| was| is)) (?:(.+?)(?:[\'’]s)? )(latest|last|previous|next|[\\d.]+)? ?release\\??$'

    getType: ->
        return 'ReleaseReadAction'

    describe: ->
        return 'get info about releases'

    # if one of these matches, this Action will be run
    getPatternRegex: (name = null) ->
        return new Promise (resolve, reject) =>
            if @patternRegexes
                return resolve if name then @patternRegexes[name] else @patternRegexes

            @patternRegexes = {}
            return @customer_database.model('Customer').getAllNameRegexString()
            .then (customerRegex) =>
                for own key, regex of @regex
                    regex = regex.replace '__customer__', customerRegex
                    @patternRegexes[key] = @jiri.createPattern(regex).getRegex()
                return resolve if name then @patternRegexes[name] else @patternRegexes

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        releaseVersion = null
        mode = null
        customer = null

        @getPatternRegex()
        .then (regexes) =>
            # remove question mark
            message.text = message.text.replace /\?+$/, ''
            # display release
            if m = message.text.match regexes.get1
                releaseVersion = m[1]
                customerName = m[2]
                mode = 'get'

            else if m = message.text.match regexes.get2
                customerName = m[1]
                releaseVersion = m[2]
                mode = 'get'

            else if m = message.text.match regexes.when
                customerName = m[1]
                releaseVersion = m[2]
                mode = 'when'

            Customer = @customer_database.model 'Customer'
            if mode
                releaseVersion = if releaseVersion then releaseVersion.toLowerCase() else 'latest'

                if customerName
                    Customer.findOneByName(customerName)
                else if message.channelCustomerId
                    Customer.findOne _id: message.channelCustomerId
                else
                    assert false, "Can you specify which customer / project you mean?"
        .then (c) =>
            throw new Error "Unable to find customer #{customerName}" unless c
            customer = c
            @jiri.jira.getReleaseTicket customer.project, releaseVersion
        .then (releaseTicket) =>
            if releaseTicket and typeof releaseTicket is 'object'
                return releaseTicket
            # no 'next' ticket, suggest we create one
            else if releaseVersion in ReleaseIssue.prototype.synonyms.next
                return @noNextReleaseTicket customer

        .then (releaseTicket) =>
            throw new Error "I couldn't find the appropriate release ticket" unless releaseTicket

            switch mode
                when 'when'
                    text = "#{customer.name}'s "
                    if releaseVersion in ReleaseIssue.prototype.synonyms.latest
                        text += "latest release"
                    else if releaseVersion in ReleaseIssue.prototype.synonyms.previous
                        text += "most recent completed release"
                    else if releaseVersion in ReleaseIssue.prototype.synonyms.next
                        text += "next release"
                    else
                        text += "release #{releaseVersion}"
                    text += " was created #{releaseTicket.created.calendar()} by #{releaseTicket.creator?.displayName}"
                    return text: text

                else
                    if releaseVersion in ReleaseIssue.prototype.synonyms.latest
                        text = "Here's #{customer.name}'s latest release:"
                    else if releaseVersion in ReleaseIssue.prototype.synonyms.previous
                        text = "Here's #{customer.name}'s most recent completed release:"
                    else if releaseVersion in ReleaseIssue.prototype.synonyms.next
                        text = "#{customer.name}'s next release:"
                    else
                        text = "#{customer.name} release #{releaseVersion}:"
                    return new IssueOutput(@jiri.jira, releaseTicket).getSlackMessage text

        .catch (e) =>
            # handle assertion errors as okay — just return message
            if e?.name is 'AssertionError'
                return text: e.message
            else if e.message?.match /mapped to in JIRA/
                return text: "#{e.message} — set the `_mappingId_jira` property to the `Reporting Customer` as JIRA knows it"
            else if m = e.errorMessages?[0].match /The option '(.+)' for field 'Reporting Customers' does not exist./
                return text: "The `_mappingId_jira` value `#{m[1]}` doesn't match a Reporting Customer value in JIRA"
            throw e

    noNextReleaseTicket: (customer, forceCreate = false) =>
        new Promise (resolve, reject) =>
            @jiri.recordOutcome 'AddToReleaseAction', @OUTCOME_SUGGESTION, {suggestion: "create release for #{customer.name}"}, @channel
            resolve "It doesn't look like there is an active release for #{customer.name}. Would you like to create one?"

    test: (message) ->
        @getPatternRegex().then (regexes) =>
            for own name,regex of regexes
                if message.text.match(regex)
                    return true
            return false

module.exports = ReleaseReadAction
