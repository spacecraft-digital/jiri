colors = require 'colors/safe'
Jiri = require './src/Jiri'
Crater = require 'crater'
JiriSlack = require './src/JiriSlack'
GitLab = require 'gitlab'
mc = require 'mc'
Jira = require './src/Jira'

# construct a new object, passing an array of arguments
newWithArgs = (constructor, args) ->
    F = -> return constructor.apply this, args
    F.prototype = constructor.prototype;
    return new F()

if '--debug' in process.argv
    console.log colors.bgCyan.black "  ~ DEBUG MODE ~  "

config = require './config'

# will create SSH tunnels if 'tunnels' is defined in config
# (which should only be defined in DEV config)
require('dev-tunnels') config
# get the database first, because JIRA needs it
.then -> Crater config.mongo_url
.then (customer_database) ->
    # then get the rest of the dependencies in parallel
    Promise.all [
        new JiriSlack config.slack_apiToken, config.slack_autoReconnect, config.slack_autoMark
        customer_database,
        new Jira config, customer_database
        GitLab url: config.gitlab_url, token: config.gitlab_token
        new Promise (resolve, reject) ->
            cache = new mc.Client()
            cache.connect ->
                # as this callback seems to fire even if connection
                # wasn't established, we'll test the connection with a set()
                cache.set 'connection-test', '1', {}, ->
                    console.log "Connected to memcached"
                    resolve cache
    ]

# once we've got all the dependencies, we can construct
.then (deps) -> newWithArgs Jiri, deps

.catch (e) -> console.error e
