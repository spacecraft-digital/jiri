# Developing Jiri

## Actions
Modular Actions respond to messages users send — either to Jiri or just generally

To add a new one, duplicate on of the existing ones in `src/actions/` and also add
it to the array in Jiri#loadActions (this determines the order they are called in).

A user's message will be handled by the first action to return true to its `test()` method.

In Debug Mode, Action modules (i.e. src/actions/FooAction.coffee) are reloaded on each
incoming message, so you don't need to restart Jiri to test a change to these files.

## Config
Config is defined in config.coffee. When running Jiri in `debug mode`, any config
in `config-dev.coffee` will override anything in config.coffee

### Secrets

Some config values shouldn't be in the repo on in a config file — e.g. passwords,
keys, nuclear launch codes.

There are a number of secrets that are loaded from environment variable.

The easiest way to work with this is to fill in the code below, and store this securely
in your password manager. This can be pasted into a shell before running Jiri.

```
# copy and paste this into the shell

export JIRA_PASSWORD=''
export SLACK_API_TOKEN=''
export GITLAB_TOKEN=''
export PEOPLE_CALENDAR_URL=''
export GOOGLE_PRIVATE_KEY_ID=""
export GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
…
-----END PRIVATE KEY-----
"
export GOOGLE_CLIENT_EMAIL=""
export GOOGLE_CLIENT_ID=""
export SMARTSHEET_API_KEY=""
clear && echo “Jiri env vars loaded”
```

## Tunnels

Jiri needs access to a number of services — including MongoDB and memcached.
When developing, it may be convenient to connect these to a remote server —
perhaps the main Jiri server if you're just developing a reading tool.

Any tunnels in config.tunnels will be set up when you run `npm run start-dev`

### Tunnel config
```
tunnels:
    'host1':
        ports: ['27017', '11211']
        privateKeyPath: '/path/to/key' # defaults to use config.sshPrivateKeyPath)
        username: 'mary' # defaults to root
    'host2':
        ports: ['8080']
```

