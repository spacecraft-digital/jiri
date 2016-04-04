colors = require 'colors'
RSVP = require 'rsvp'

module.exports = (config) ->
    new RSVP.Promise (resolve, reject) ->

        resolve true unless config.tunnels?.length

        fs = require 'fs'
        async = require 'async'
        tunnel = require('tunnel-ssh')

        tunnels = []
        for host, opts of config.tunnels
            if typeof opts is 'string'
                opts = { ports: [opts] }
            else if Array.isArray(opts)
                opts = { ports: opts }
            opts.privateKeyPath = opts.privateKeyPath||config.sshPrivateKeyPath
            opts.privateKey = fs.readFileSync opts.privateKeyPath
            opts.username = 'root' unless opts.user
            for port in opts.ports
                o = {}
                o[k] = v for k, v of opts when k not in ['port', 'ports', 'privateKeyPath']
                o.host = host
                o.localHost = '127.0.0.1'
                o.localPort = port
                o.dstPort = port
                console.log colors.bgCyan.black "Tunneling port #{o.dstPort} to #{o.host} as #{o.username} using #{opts.privateKeyPath}"
                tunnels.push do (o) -> (done) -> tunnel o, done

        return resolve false unless tunnels.length

        resolve async.parallel tunnels, (err, results) -> resolve true

    .catch (e) ->
        console.log colors.red e.stack
        throw "Unable to tunnel connections"
