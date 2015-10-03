RSVP = require 'rsvp'
Action = require './Action'
config = require '../../config'
mongoose = require '../../database_init'
Customer = mongoose.model 'Customer'
ReleaseIssue = require '../ReleaseIssue'
IssueOutput = require '../IssueOutput'

class ReleaseAction extends Action

    # what's oxford's latest release
    # get oxford's latest release
    # show oxford's latest release
    # show oxford release 1.3
    regex:
        get1: '^jiri (?:what(?:[\'’]s| is)|show|find|get) (?:the )?(latest|last|previous|next|\\d.\\d(?:.\\d)?)? ?release(?: for (.+))?\\??$'
        get2: '^jiri (?:what(?:[\'’]s| is)|show|find|get) (?:(.+?)(?:[\'’]s)? )(latest|last|previous|next|[\\d.]+)? ?release\\??$'
        add: '^jiri add ([A-Z]{2,5}-[0-9]{2,5}) to (?:(.+) )release(?: ([\\d.]+))?$'

    getType: ->
        return 'ReleaseAction'

    describe: ->
        return 'create and manage releases'

    # if one of these matches, this Action will be run
    getPatternRegex: (name = null) ->
        unless @patternRegexes
            @patternRegexes = {}
            @patternRegexes[key] = @jiri.createPattern(regex).getRegex() for key, regex of @regex
        return if name then @patternRegexes[name] else @patternRegexes

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            # remove question mark
            message.text = message.text.replace /\?+$/, ''

            found = false

            # display release
            if m = message.text.match @getPatternRegex('get1')
                releaseVersion = m[1]
                customerName = m[2]
                found = true

            else if m = message.text.match @getPatternRegex('get2')
                customerName = m[1]
                releaseVersion = m[2]
                found = true

            if found
                customer = null
                releaseVersion = if releaseVersion then releaseVersion.toLowerCase() else 'latest'

                @setLoading()
                Customer.findOneByName(customerName)
                .then (c) =>
                    return reject "Unable to find customer #{customerName}" unless c
                    customer = c
                    @setLoading()
                    @jiri.jira.getReleaseTicket customer.project, releaseVersion
                .catch reject
                .then (releaseTicket) =>
                    return releaseTicket if releaseTicket

                    # no 'next' ticket, suggest we create one
                    if releaseVersion in ReleaseIssue.prototype.synonyms.next
                        return @noNextReleaseTicket customer
                                .then (releaseTicket) =>
                                    if typeof releaseTicket is 'string'
                                        resolve
                                            text: releaseTicket
                                            channel: @channel.id
                                    else
                                        return releaseTicket

                .then (releaseTicket) =>
                    return reject "I couldn't find the appropriate release ticket" unless releaseTicket

                    outputter = new IssueOutput releaseTicket
                    response = outputter.getSlackMessage()

                    if releaseVersion in ReleaseIssue.prototype.synonyms.latest
                        text = "Here's #{customer.name}'s latest release:"
                    else if releaseVersion in ReleaseIssue.prototype.synonyms.previous
                        text = "Here's #{customer.name}'s most recent completed release:"
                    else if releaseVersion in ReleaseIssue.prototype.synonyms.next
                        text = "#{customer.name}'s next release:"
                    else
                        text = "#{customer.name} release #{releaseVersion}:"

                    response.text = text
                    response

                .then (response) =>
                    response.channel = @channel.id
                    return resolve response

                return

            if m = message.text.match @getPatternRegex('add')
                [..., ref, customerName, releaseVersion] = m

                latestRelease = !releaseVersion or releaseVersion.toLowerCase() is 'latest'

                Customer.findOneByName(customerName)
                .then (c) =>
                    return reject "Unable to find customer #{customerName}" unless c
                    customer = c
                    @jiri.jira.getReleaseTicket customer.project, releaseVersion
                .catch reject
                .then (releaseTicket) =>
                    return reject "I couldn't find the appropriate release ticket" unless releaseTicket

                    @jiri.jira.createLink releaseTicket.key, ref
                    .then ->
                        console.log 'link created', arguments
                        resolve
                            text: "Link created between #{releaseTicket.ref} and #{ref}"
                            channel: @channel.id

    noNextReleaseTicket: (customer, forceCreate = false) =>
        new RSVP.Promise (resolve, reject) =>
            resolve "It doesn't look like there is an active release for #{customer.name}. Would you like to create one?"

    test: (message) ->
        new RSVP.Promise (resolve) =>
            for own name,regex of @getPatternRegex()
                if message.text.match(regex)
                    return resolve true
            return resolve false

module.exports = ReleaseAction
