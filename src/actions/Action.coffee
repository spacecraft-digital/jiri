
# abstract
class Action

    constructor: (@jiri, @channel) ->

    # should return the class name as a string
    getType: ->
        throw 'Action subclass needs to implement getType method'
        # return 'Action'

    # return a string that describes what this action enables Jira to do
    describe: ->

    respondTo: (message) ->
        throw 'Action subclass needs to implement respondTo method'

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        throw 'Action subclass needs to implement test method'

    # Make Slack say “Jiri is typing” to show the user that something is happening
    setLoading: () =>
        @jiri.slack.setTyping @channel.id

    # Return true if other actions can run
    # Return false if this action has handled this message, and no other actions should be triggered
    allowOtherActions: ->
        false

module.exports = Action
