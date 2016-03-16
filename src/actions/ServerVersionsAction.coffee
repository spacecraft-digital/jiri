RSVP = require 'rsvp'
Action = require './Action'
config = require '../../config'
https = require 'https'
node_ssh = require 'node-ssh'
stringUtils = require '../utils/string'

class ServerVersionsAction extends Action

    getType: ->
        return 'ServerVersionsAction'

    describe: ->
        return 'reads installation version numbers from servers via SSH'

    # if one of these matches, this Action will be run
    getTestRegex: ->
        [
            '^jiri (?:which|what|show) versions? (?:are|is)? (?:installed)? on (?:<http[^|]+\\|)?([a-z.0-9\\-]+)>?(?: (qa|uat|dev))? ?(?:site|server)?\\??$',
        ]

    constructor: (@jiri, @channel) ->

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            sshUser = 'root'

            for regex in @getTestRegex()
                if m = message.text.toLowerCase().match @jiri.createPattern(regex).getRegex()
                    server = m[1]
                    if m[2] and not server.match /\./
                        server += '--' + m[2]
                    if not server.match /\./
                        server = server + '.ntn.jadu.net'

            customer = server.replace /^(\w+).+/, '$1'

            ssh = new node_ssh

            versionsCommand = """
                cd /var/www/jadu;for f in $(ls -1 *VERSION);do;echo -n "$f: ";head -n1 $f|tr -d '\n';echo;done
            """

            @setLoading()
            ssh.connect(
                host: server,
                username: sshUser,
                privateKey: config.sshPrivateKeyPath
            ).then =>
                @setLoading()
                ssh.execCommand(versionsCommand, {stream: 'both'})
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
                if error.errno is 'ENOTFOUND'
                    return resolve
                        text: "#{error.hostname} isn't available — have you spelt it right?"
                        channel: @channel.id
                else if error.level is 'client-authentication'
                    return resolve
                        text: "Sorry — I wasn't allowed in to #{server} with my :key:, so I don't know. Try http://#{server}/jadu/version.php"
                        channel: @channel.id
                else
                    console.log error
                    return resolve
                        text: "I tried to SSH into #{server} to get the versions. It didn't work. :cry:"
                        channel: @channel.id

    test: (message) ->
        new RSVP.Promise (resolve) =>
            return resolve false unless message.type is 'message' and message.text? and message.channel?

            for regex in @getTestRegex()
                console.log @jiri.createPattern(regex).getRegex()
                if message.text.match @jiri.createPattern(regex).getRegex()
                    return resolve true

            return resolve false

module.exports = ServerVersionsAction
