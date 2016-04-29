Action = require './Action'
config = require '../../config'
ReleaseIssue = require '../ReleaseIssue'
IssueOutput = require '../IssueOutput'

class ReleaseWriteAction extends Action

    regex:
        add: '^jiri add ([A-Z]{2,5}-[0-9]{2,5}) to (?:(.+) )release(?: ([\\d.]+))?$'
        create: '^jiri (?:create|make|new) (?:a )?(?:new )?release for __customer__$'

    getType: ->
        return 'ReleaseWriteAction'

    describe: ->
        return 'create and manage releases'

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
        @getPatternRegex()
        .then (regexes) =>
            # remove question mark
            message.text = message.text.replace /\?+$/, ''

            mode = null
            Customer = @customer_database.model 'Customer'

            if m = message.text.match regexes.add
                [..., ref, customerName, releaseVersion] = m

                latestRelease = !releaseVersion or releaseVersion.toLowerCase() is 'latest'

                Customer.findOneByName(customerName)
                .then (c) =>
                    throw new Error "Unable to find customer #{customerName}" unless c
                    customer = c
                    @jiri.jira.getReleaseTicket customer.project, releaseVersion
                .catch reject
                .then (releaseTicket) =>
                    throw new Error "I couldn't find the appropriate release ticket" unless releaseTicket

                    @jiri.jira.createLink releaseTicket.key, ref
                    .then =>
                        console.log 'link created', arguments
                        text: "Link created between #{releaseTicket.ref} and #{ref}"
                        channel: @channel.id

    noNextReleaseTicket: (customer, forceCreate = false) =>
        new Promise (resolve, reject) =>
            @jiri.recordOutcome @, @OUTCOME_SUGGESTION, {suggestion: "create release for #{customer}"}
            resolve "It doesn't look like there is an active release for #{customer.name}. Would you like to create one?"

    test: (message) ->
        @getPatternRegex()
        .then (regexes) ->
            for own name,regex of regexes
                if message.text.match(regex)
                    return true
            return false

module.exports = ReleaseWriteAction
