# DEVELOPMENT Config
# When running in debug mode, anything here will override what's in config.json

colors = require 'colors'
joinn = require 'joinn'

config =
    calendarChannel: 'zapier-test'
    sshPrivateKeyPath: '/Users/mattd/.ssh/jadu_webdev_key'
    tunnels:
        'spacecraft--jiri.ntn.jadu.net':
            ports: ['27017', '11211']
            # privateKeyPath: '/path/to/key' (defaults to use config.sshPrivateKeyPath)
            # username: 'root'

    # only these users can talk to Jiri in debug mode
    slack_userId_whitelist: [
        'U025466D6' # matt.dolan
    ]
    # users / channels to notify of app events such as start up and restart
    slack_processAlerts: [
        '@matt.dolan'
    ]

console.log colors.bgCyan.black "Using DEV config for #{joinn Object.keys(config)}"

module.exports = config
