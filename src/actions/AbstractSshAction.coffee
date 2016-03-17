RSVP = require 'rsvp'
Action = require './Action'
config = require '../../config'
https = require 'https'
node_ssh = require 'node-ssh'
stringUtils = require '../utils/string'

# an abstract action for SSH actions to extend
class AbstractSshAction extends Action

    constructor: (@jiri, @channel) ->
        @ssh = new node_ssh

    # subclasses should override this
    getPatterns: ->
        []

    getPatternParts: ->
        "server": "(the )?(<http[^|]+\\|)?([a-z.0-9\\-]+)>?(['’]s)?( (qa|uat|dev pod|dev|[a-z]{3,4}-\\d{3,}\\b))? ?(site|server)?"

    # if one of these matches, this Action will be run
    getTestRegex: =>
        (@jiri.createPattern(pattern, @getPatternParts()).getRegex() for pattern in @getPatterns())

    # takes one of the following:
    # full server domain name (e.g. foo--dev.ntn.jadu.net)
    # IP address
    # first part of the server name (e.g. foo--dev)
    # customer name and server role (e.g. foo dev)
    #
    # and returns a full server hostname (e.g. foo--dev.ntn.jadu.net)
    normaliseServerName: (server) ->
        # remove hyperlink markup
        server = server.replace /^(?:<http[^|]+\|)?([a-z.0-9\-]+)>?$/i, '$1'
                       # remove meaningless leading words
                       .replace /^the +/i, ''
                       # remove meaningless trailing words
                       .replace /[ ]+(site|server)$/i, ''
                       # remove apostrophe-s of possession
                       .replace /['’]s\b/, ''
                       .toLowerCase()

        # assume a JIRA ref means a pod
        if m = server.match /^([^ ]+) +(dev pod|[a-z]{3,4}-\d{3,})$/i
            [x, client, role] = m
            role = 'dev' if role is 'dev pod'
            return "#{role}.#{client}.pods.jadu.net"
        else if server.indexOf(' ') > -1
            server = server.split(' ').join('--')

        if not server.match /\./
            server = server + '.ntn.jadu.net'
        server

    deriveCustomerName: (server) ->
        # if the server name is an IP Address, we can't extract the customer name
        if server.match /^[\d\.]$/
            return 'Client'
        else
            return server.replace /^(\w+).+/, '$1'

    # Guess the Jadu installation path
    # If it's a pod, return the pod path.
    # Otherwise assume /var/www/jadu
    #
    # Pass a *normalised* server name (i.e. the full domain name)
    getJaduPath: (server) ->
        if m = server.match /^([a-z0-9\-]+)\.([a-z0-9\-]+)\.pods\.jadu\.net$/
            [x, pod, client] = m
            return "/var/www/clients/#{client}/#{pod}"
        else
            return "/var/www/jadu"

    # returns a Promise that will resolve upon connection
    connectToServer: (server) =>
        return new RSVP.Promise (resolve, reject) =>
            @setLoading()
            @ssh.connect(
                host: server,
                username: config.sshUser,
                privateKey: config.sshPrivateKeyPath
            )
            .then resolve
            .catch (error) =>
                if error.errno is 'ENOTFOUND'
                    return reject "#{error.hostname} isn't available — have you spelt it right?"
                else if error.level is 'client-authentication'
                    return reject "Sorry — I wasn't allowed into #{server} with my key, so I don't know."
                else
                    console.log error
                    return reject "I tried to SSH into #{server}. It didn't work. :cry:"

    test: (message) ->
        new RSVP.Promise (resolve) =>
            return resolve false unless message.type is 'message' and message.text? and message.channel?

            for regex in @getTestRegex()
                if message.text.match regex
                    return resolve true

            return resolve false

module.exports = AbstractSshAction
