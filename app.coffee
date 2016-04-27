colors = require 'colors/safe'

if '--debug' in process.argv
    console.log colors.bgCyan.black "  ~ DEBUG MODE ~  "

config = require './config'
RSVP = require 'rsvp'

# will create SSH tunnels if 'tunnels' is defined in config
# (which should only be defined in DEV config)
require('dev-tunnels') config
.then ->
    dependencies =
        customer_database: require('crater') config.mongo_url
        slack: new RSVP.Promise (resolve, reject) ->
            resolve new (require './src/JiriSlack') config.slack_apiToken, config.slack_autoReconnect, config.slack_autoMark
        gitlab: new RSVP.Promise (resolve, reject) ->
            resolve (require 'gitlab') url: config.gitlab_url, token: config.gitlab_token
        cache: new RSVP.Promise (resolve, reject) ->
            mc = require 'mc'
            cache = new mc.Client()
            cache.connect ->
                # as this callback seems to fire even if connection
                # wasn't established, we'll test the connection with a set()
                cache.set 'connection-test', '1', {}, ->
                    console.log "Connected to memcached"
                    resolve cache

    return RSVP.hash dependencies

.then (deps) ->
    deps.jira = new (require './src/Jira') config, deps.customer_database
    jiri = new (require './src/Jiri') deps.slack, deps.customer_database, deps.jira, deps.gitlab, deps.cache

.catch (e) -> console.error e
