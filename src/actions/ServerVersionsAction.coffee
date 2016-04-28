RSVP = require 'rsvp'
AbstractSshAction = require './AbstractSshAction'
config = require '../../config'
https = require 'https'
titlecase = require 'titlecase'
node_ssh = require 'node-ssh'

class ServerVersionsAction extends AbstractSshAction

    getType: ->
        return 'ServerVersionsAction'

    describe: ->
        return 'reads installation version numbers from servers via SSH'

    # if one of these matches, this Action will be run
    getPatterns: ->
        [
            '(?:which versions? are?|what(?:[\'s’]?s| is)) (?:installed )?on (server)\\??$',
        ]

    getPatternParts: ->
        parts = super()
        parts.which = "which|what|show"
        parts.are = "are|is"
        parts

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        for regex in @getTestRegex()
            if m = message.text.toLowerCase().match regex
                server = @normaliseServerName m[1]
                break

        if server is null
            return {
                text: "Sorry, that isn't a server I can work with :no_entry:"
                channel: @channel.id
            }

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
                        when 'CLIENT_VERSION' then app = titlecase customer.toLowerCase()
                        else
                            app = titlecase file.replace('_VERSION', '').replace('_', ' ').toLowerCase()
                    "*#{app}* `#{version}`"

                text: """
                    #{server} has the following software installed:
                    #{versions.join '\n'}
                """
                channel: @channel.id

        .catch (error) =>
            message =
                if error.message?.match /I wasn't allowed into/
                    error.message + " Try http://#{server}/jadu/version.php"
                else
                    "unable to retrieve version numbers"
            text: message
            channel: @channel.id

module.exports = ServerVersionsAction
