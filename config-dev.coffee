# DEVELOPMENT Config
# When running in debug mode, anything here will override what's in config.json

config =
    calendarChannel: 'zapier-test'

console.log "Using DEV config for #{Object.keys(config).join(', ')}"

module.exports = config
