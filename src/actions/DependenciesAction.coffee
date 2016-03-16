RSVP = require 'rsvp'
Action = require './Action'
Issue = require '../Issue'
IssueOutput = require '../IssueOutput'
config = require '../../config'
https = require 'https'

class DependenciesAction extends Action

    getType: ->
        return 'DependenciesAction'

    describe: ->
        return 'looks up dependency versions for certain products'

    # if one of these matches, this Action will be run
    getTestRegex: ->
        {
            xfp: [
                '^jiri (?:which|what) (?:CMS(?: version)?|version of (?:the )CMS)? (?:does|is) XFP (#?[\\d.]+) (?:support|need|require|work with|want|compatible with)',
                '^jiri (?:should|does|is) XFP (#?[\\d.]+) (?:work with|support|compatible with) CMS (?:[\\d.]+)'
            ]
        }

    constructor: (@jiri, @channel) ->

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            product = null
            version = null
            dependency = 'CMS'

            for p, regexes of @getTestRegex()
                for regex in regexes
                    if m = message.text.match @jiri.createPattern(regex).getRegex()
                        product = p
                        version = m[1]

            if m = version.match /^#?(\d+)$/
                if m[1] >= 22
                    version = '3.2.' + m[1]
                else
                    version = '1.3.2.' + m[1]

            switch product
                when 'xfp'
                    product = 'XFP'
                    url = "https://gitlab.hq.jadu.net/xfp/1-3-2/raw/#{version}/MODULE_CMS_DEPENDENCY"
                else
                    return resolve false

            request = https.get url, (response) =>
                s = ''
                response.on 'data', (chunk) ->
                  s += chunk

                response.on 'end', =>
                    switch response.statusCode
                        when 404
                            return resolve
                                text: "`#{version}` doesn't seem to be a valid #{product} version tag"
                                channel: @channel.id
                        when 200
                            if s.match /^\s*[\d.]+\s*$/
                                return resolve
                                    text: "#{product} #{version} requires #{dependency} #{s}"
                                    channel: @channel.id
                            else
                                return resolve
                                    text: "¯\\_(ツ)_/¯ I'm afraid I don't know what #{dependency} version #{product} requires"
                                    channel: @channel.id
                        else
                            return resolve
                                text: "Sorry, I wasn't able to check with the #{product} repo on GitLab"
                                channel: @channel.id

            request.end()

    test: (message) ->
        new RSVP.Promise (resolve) =>
            return resolve false unless message.type is 'message' and message.text? and message.channel?

            for product, regexes of @getTestRegex()
                for regex in regexes
                    if message.text.match @jiri.createPattern(regex).getRegex()
                        return resolve true

            return resolve false

module.exports = DependenciesAction
