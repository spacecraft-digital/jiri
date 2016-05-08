colors = require 'colors/safe'
Jiri = require './src/Jiri'
Crater = require 'crater'
JiriSlack = require './src/JiriSlack'
GitLab = require 'gitlab'
mc = require 'mc'
Jira = require 'jadu-jira'

# construct a new object, passing an array of arguments
newWithArgs = (constructor, args) ->
    F = -> return constructor.apply this, args
    F.prototype = constructor.prototype;
    return new F()

if '--debug' in process.argv
    console.log colors.bgCyan.black "  ~ DEBUG MODE ~  "

config = require './config'

getMemcachedConnection = ->
    new Promise (resolve, reject) ->
        cache = new mc.Client config.memcached_hosts
        cache.connect ->
            # as this callback seems to fire even if connection
            # wasn't established, we'll test the connection with a set()
            cache.set 'connection-test', '1', {}, ->
                console.log "Connected to memcached"
                resolve cache

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
        new Jira {user: config.jira_user, password: config.jira_password}, database
        GitLab url: config.gitlab_url, token: config.gitlab_token
        getMemcachedConnection()
    ]
.catch (err) ->
    throw colors.bgRed 'Failed to load dependencies: ' + err.stack||err

# once we've got all the dependencies, we can construct
.then (deps) ->
    jiri = newWithArgs Jiri, deps
    jiri.on 'memcached:connection_error', ->
        console.log 'Memcached connection error — attemping to recreate connection'
        # create a new Memcached connection
        getMemcachedConnection().then (cache) ->
            # and replace the existing one
            jiri.cache = cache

.catch (e) -> console.error e.stack || e
