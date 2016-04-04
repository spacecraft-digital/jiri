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

console.log colors.bgCyan.black "Using DEV config for #{joinn Object.keys(config)}"

module.exports = config
