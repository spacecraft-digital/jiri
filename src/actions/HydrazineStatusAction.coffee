AbstractSshAction = require './AbstractSshAction'
config = require '../../config'
https = require 'https'
titlecase = require 'titlecase'
node_ssh = require 'node-ssh'
converter = require 'number-to-words'

class HydrazineStatusAction extends AbstractSshAction

    getType: ->
        return 'HydrazineStatusAction'

    describe: ->
        return 'reports on Hydrazine build status/queue'

    # if one of these matches, this Action will be run
    getPatterns: ->
        [
            'hydrazine status',
            'what\'s hydrazine doing',
            'is hydrazine down',
        ]

    getPodNameFromObject: (o) ->
        if o.ref and o.project.path_with_namespace
            pod = o.ref.replace(/^refs\/heads\/(feature\/)?/, '').replace(/[^a-z0-9-]+/,'-').toLowerCase()
            customer = o.project.path_with_namespace.replace(/^.+\/([a-z0-9-]+)$/, '$1')
            "#{pod}.#{customer}.pods.jadu.net"
        else if o.client and o.branch
            "#{o.branch}.#{o.client}.pods.jadu.net"

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->

        @connectToServer 'all.pods.jadu.net'
        .then =>
            Promise.all [
                @ssh.execCommand('cat /var/www/.hydrazine/receive/var/received_requests/*', {stream: 'both'})
                @ssh.execCommand('cat /var/www/.hydrazine/receive/var/tmp/*', {stream: 'both'})
            ]
            .then ([queue, current]) =>
                console.log queue, current
                if current.stdout
                    o = JSON.parse current.stdout
                    message = "*Hydrazine is working on #{@getPodNameFromObject(o)}*"
                else
                    message = "*No pod is currently being built*"

                if queue.stdout.length
                    pods = for file in queue.stdout.replace('}{','}•{').split('•')
                        @getPodNameFromObject JSON.parse(file)

                    message += "\n\n*With #{converter.toWords pods.length} politely waiting their turn:*\n#{pods.join("\n")}"
                else
                    message += "\n\n(and none are waiting to be processed)"

                text: message

        .catch (error) =>
            console.log error.stack||error
            text: "For some reason I couldn't get Hydrazine's status"

module.exports = HydrazineStatusAction
