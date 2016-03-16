
config = require './config'
JiriSlack = require './src/JiriSlack'

console.log "DUMPING SLACK USERS…"

slack = new JiriSlack(
    config.slack_apiToken,
    config.slack_autoReconnect,
    config.slack_autoMark
)

slack.on 'open', ->
    for own id, user of slack.users
        if user.is_bot
            console.log "#{user.id}  @#{user.name} [bot]"
        else
            console.log "#{user.id}  @#{user.name} — <#{user.real_name}> #{user.profile?.email}"
    slack.disconnect()

slack.on 'error', (error) -> console.log "Slack error: ", error

slack.login()
