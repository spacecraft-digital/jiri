AbstractSshAction = require './AbstractSshAction'
config = require '../../config'
moment = require 'moment'
joinn = require 'joinn'
node_ssh = require 'node-ssh'

class ServerLogAction extends AbstractSshAction

    getType: ->
        return 'ServerLogAction'

    describe: ->
        return 'parses log file from servers via SSH'

    getPatterns: ->
        [
            "whats wrong with (server)\\??$",
            "what errors are on (server)\\??$",
            "show errors on (server)\\??$",
            "show (server) log",
            "show log for (server)\\??$",
            "whats in the log for (server)\\??$"
        ]

    getPatternParts: ->
        parts = super()
        parts["show"] = "show|list"
        parts["whats"] = "what's|what is"
        parts["wrong"] = "wrong|up|failing|erroring|logged|broken?|borked"
        parts["for"] = "for|on"
        parts["with"] = "with|on"
        parts["log"] = "logs?"
        parts

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        return new Promise (resolve, reject) =>
            for regex in @getTestRegex()
                if m = message.text.toLowerCase().match regex
                    server = @normaliseServerName m[1]
                    break

            if server is null
                return resolve
                    text: "Sorry, that's not a server I can work with"
                    channel: @channel.id

            customer = @deriveCustomerName server

            jaduPath = @getJaduPath server
            logPath = '/logs/php_log'

            tailCommand = """
                tail -n100 #{jaduPath}#{logPath}
            """

            @connectToServer(server)
            .then =>
                @setLoading()
                @ssh.execCommand(tailCommand, {stream: 'both'})
                .then (result) =>
                    if result.stderr.match /cannot open .+No such file/i
                        if server.match /\.pods\.jadu\.net$/i
                            # read pods for that customer
                            cmd = "ls -1 #{jaduPath.replace /\/[a-z0-9\-]+$/, '/'}"
                            return @ssh.execCommand(cmd, {stream: 'both'})
                            .then (result) =>
                                # something's wrong
                                if result.stderr
                                    return resolve
                                        text: "There is no pod #{server} — something's wrong somewhere…"
                                        channel: @channel.id
                                # we've got a list of pods
                                else
                                    pods = (pod for pod in result.stdout.split "\n" when not pod.match /^(\s*|dev|logs)$/)
                                    return resolve
                                        text: """
                                            There is no pod #{server}. Did you mean one of these?
                                            #{joinn pods, ', ', ' or '}
                                        """
                                        channel: @channel.id
                        else
                            return resolve
                                text: "I expected there to be a log at #{jaduPath}#{logPath} on #{server}, but it wasn't there :confused:"
                                channel: @channel.id

                    errors = []
                    now = moment()
                    for line in result.stdout.split('\n') when line.match /PHP (Warning|.+\bError)/i
                        continue unless m = line.match /^\[([\da-z\-: ]+)\] ([\w ]+): *(.+)$/i
                        [x, date, errorType, message] = m
                        date = moment.utc date, 'DD-MMM-YYYY HH:mm:ss'
                        if now.diff(date, 'hours') < 1
                            message = message
                                        .replace new RegExp("#{jaduPath}/",'g'), ''
                                        # special case for Hydrazine release folder paths
                                        .replace new RegExp('^/var/www/clients/[^/]+/.pods/[^/]+/releases/\\d+/'), ''
                                        .replace ' in Unknown on line 0', ''

                            errors.push """
                                *#{errorType}* #{date.fromNow()}
                                ```
                                #{message}
                                ```
                            """

                    if errors.length > 3
                        errors = errors.slice -3

                    if errors.length is 0
                        return resolve
                            text: "There haven't been _any_ PHP errors on `#{server}` in the last hour :sunglasses:"
                            channel: @channel.id
                    else
                        return resolve
                            text: """
                                Recent PHP errors on #{server}:
                                #{errors.join '\n'}
                            """
                            channel: @channel.id
            .catch (error) =>
                resolve
                    text: error
                    channel: @channel.id

module.exports = ServerLogAction
