RSVP = require 'rsvp'
AbstractSshAction = require './AbstractSshAction'
config = require '../../config'
https = require 'https'
node_ssh = require 'node-ssh'
stringUtils = require '../utils/string'

class ServerVersionsAction extends AbstractSshAction

    getType: ->
        return 'ServerVersionsAction'

    describe: ->
        return 'reads installation version numbers from servers via SSH'

    # if one of these matches, this Action will be run
    getPatterns: ->
        [
            'which versions? are? (?:installed)? on (server)\\??$',
        ]

    getPatternParts: ->
        parts = super()
        parts.which = "which|what|show"
        parts.are = "are|is"
        parts

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            for regex in @getTestRegex()
                if m = message.text.toLowerCase().match regex
                    server = @normaliseServerName m[1]
                    break

            if server is null
                return resolve
                    text: "Sorry, that isn't a server I can work with :no_entry:"
                    channel: @channel.id

            customer = @deriveCustomerName server
            jaduPath = @getJaduPath server

            versionsCommand = """
                cd #{jaduPath};for f in $(ls -1 *VERSION);do echo -n "$f: ";head -n1 $f|tr -d '\n';echo;done
            """

            @connectToServer(server)
            .then =>
                @setLoading()
                @ssh.execCommand(versionsCommand, {stream: 'both'})
                .then (result) =>
                    versions = for line in result.stdout.split('\n')
                        [file, version] = line.split(': ', 2)
                        continue unless file
                        switch file.toUpperCase()
                            when 'VERSION' then app = 'CMS'
                            when 'XFP_VERSION' then app = 'XFP'
                            when 'CLIENT_VERSION' then app = stringUtils.titleCase customer
                            else
                                app = stringUtils.titleCase file.replace('_VERSION', '').replace('_', ' ')
                        "*#{app}* `#{version}`"

                    return resolve
                        text: """
                            #{server} has the following software installed:
                            #{versions.join '\n'}
                        """
                        channel: @channel.id

            .catch (error) =>
                if error.match /I wasn't allowed into/
                    error += " Try http://#{server}/jadu/version.php"
                resolve
                    text: error
                    channel: @channel.id

module.exports = ServerVersionsAction
