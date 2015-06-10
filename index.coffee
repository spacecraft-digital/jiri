# This is a simple example of how to use the slack-client module in CoffeeScript. It creates a
# bot that responds to all messages in all channels it is in with a reversed
# string of the text received.
#
# To run, copy your token below, then, from the project root directory:
#
# To run the script directly
#    npm install
#    node_modules/coffee-script/bin/coffee examples/simple_reverse.coffee 
#
# If you want to look at / run / modify the compiled javascript
#    npm install
#    node_modules/coffee-script/bin/coffee -c examples/simple_reverse.coffee 
#    cd examples
#    node simple_reverse.js
#

Slack = require 'slack-client'

token = process.env.SLACK_API_TOKEN;
autoReconnect = true
autoMark = true

slack = new Slack(token, autoReconnect, autoMark)

config = require('./config')
config.password = process.env.JIRA_PASSWORD || config.password
JiraApi = require('jira').JiraApi
jira = new JiraApi('https', config.host, config.port, config.user, config.password, 'latest', true)

slack.on 'open', ->
  channels = []
  groups = []
  unreads = slack.getUnreadCount()

  # Get all the channels that bot is a member of
  channels = ("##{channel.name}" for id, channel of slack.channels when channel.is_member)

  # Get all groups that are open and not archived 
  groups = (group.name for id, group of slack.groups when group.is_open and not group.is_archived)

  console.log "Welcome to Slack. You are @#{slack.self.name} of #{slack.team.name}"
  console.log 'You are in: ' + channels.join(', ')
  console.log 'As well as: ' + groups.join(', ')

  messages = if unreads is 1 then 'message' else 'messages'

  console.log "You have #{unreads} unread #{messages}"


slack.on 'message', (message) ->
  channel = slack.getChannelGroupOrDMByID(message.channel)
  user = slack.getUserByID(message.user)
  response = ''

  {type, ts, text} = message

  channelName = if channel?.is_channel then '#' else ''
  channelName = channelName + if channel then channel.name else 'UNKNOWN_CHANNEL'

  userName = if user?.name? then "@#{user.name}" else "UNKNOWN_USER"

  console.log """
    Received: #{type} #{channelName} #{userName} #{ts} "#{text}"
  """

  # Respond to messages with the reverse of the text received.
  if type is 'message' and text? and channel?
    m = text.match(/\b(SPC-[0-9]{3,6})/i);
    if m
      jira.findIssue m[1], (error, issue) ->
        if error
          console.log "Jira error: #{error}"
        else
          customer = issue.fields.customfield_10025.pop()
          customerName = if customer then customer.value else '(unknown)'

          switch issue.fields.issuetype.name
            when 'Release'
              version = issue.fields.summary.match(/\d+\.\d+/)
              response = customerName + ' *' + version[0] + '*: _' + issue.fields.status.name + '_' + "\n" +
                          'https://' + config.host + '/browse/' + issue.key;

              for subtask in issue.fields.subtasks
                do (subtask) ->
                  response += "\n" + ' • ' + subtask.fields.summary + ': _' + subtask.fields.status.name + '_'

              if issue.fields.customfield_10202
                response += "\n*Deployment notes:*\n>>>" + issue.fields.customfield_10202

            else
              response = issue.fields.issuetype.name + ' ' + issue.key + ' for _' + customerName +  '_ is *' + issue.fields.status.name + '* ' + "\n" +
                          '> ' + issue.fields.summary + "\n" +
                          'https://' + config.host + '/browse/' + issue.key;
          channel.send response
          console.log """
            @#{slack.self.name} responded with "#{response}"
          """
  else
    #this one should probably be impossible, since we're in slack.on 'message' 
    typeError = if type isnt 'message' then "unexpected type #{type}." else null
    #Can happen on delete/edit/a few other events
    textError = if not text? then 'text was undefined.' else null
    #In theory some events could happen with no channel
    channelError = if not channel? then 'channel was undefined.' else null

    #Space delimited string of my errors
    errors = [typeError, textError, channelError].filter((element) -> element isnt null).join ' '

    console.log """
      @#{slack.self.name} could not respond. #{errors}
    """


slack.on 'error', (error) ->
  console.error "Error: #{error}"


slack.login()

# Bind to port so Heroku is happy
http = require 'http';

http.createServer((request, response) ->
  response.writeHead(200, { 'Content-Type': 'text/plain' });
  response.end('Running as Slack bot', 'utf-8');

).listen(process.env.PORT);
