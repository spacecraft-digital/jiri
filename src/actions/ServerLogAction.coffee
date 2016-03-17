RSVP = require 'rsvp'
AbstractSshAction = require './AbstractSshAction'
config = require '../../config'
moment = require 'moment'
node_ssh = require 'node-ssh'
stringUtils = require '../utils/string'

class ServerLogAction extends AbstractSshAction

    getType: ->
        return 'ServerLogAction'

    describe: ->
        return 'parses log file from servers via SSH'

    getPatterns: ->
        [
            "whats wrong with (server)",
            "what errors are on (server)",
            "show errors on (server)",
            "show (server) log",
            "show log for (server)",
            "whats in the log for (server)"
        ]

    getPatternParts: ->
        "show": "show|list"
        "whats": "what['’]?s|what is"
        "wrong": "wrong|up|failing|erroring|logged|broken?|borked"
        "for": "for|on"
        "with": "with|on"
        "server": "(<http[^|]+\\|)?([a-z.0-9\\-]+)>? ?(qa|uat|dev)? ?(site|server)?"

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            for regex in @getTestRegex()
                if m = message.text.toLowerCase().match regex
                    server = @normaliseServerName m[1], m[2]
                    break

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
                    errors = []
                    now = moment()
                    for line in result.stdout.split('\n') when line.match /PHP (Warning|.+\bError)/i
                        continue unless m = line.match /^\[([\da-z\-: ]+)\] ([\w ]+): *(.+)$/i
                        [x, date, errorType, message] = m
                        date = moment date, 'DD-MMM-YYYY HH:mm:ss'
                        if now.diff(date, 'hours') < 1
                            message = message
                                        .replace new RegExp("#{jaduPath}/",'g'), ''
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
