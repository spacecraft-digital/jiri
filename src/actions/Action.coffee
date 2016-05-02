
# abstract
class Action

    constructor: (@jiri, @customer_database, @channel) ->

    # should return the class name as a string
    getType: ->
        throw new Error 'Action subclass needs to implement getType method'

    # return a string that describes what this action enables Jira to do
    describe: ->

    respondTo: (message) ->
        throw new Error 'Action subclass needs to implement respondTo method'

    # Returns a Promise that resolves to something Truthy if this action can respond to the message
    # No further actions will be tested if this resolves truthily
    #
    # If the Promise resolves to the string 'ignore', no other Actions will be tested,
    # but the respondTo method will NOT be called
    test: (message) ->
        throw new Error 'Action subclass needs to implement test method'

    # Make Slack say “Jiri is typing” to show the user that something is happening
    setLoading: () =>
        @jiri.slack.setTyping @channel.id

    # returns a Pattern made from the specified patternPart
    getRegex: (part, whole = true) ->
        return null unless @patternParts[part]
        partRegex = @patternParts[part]
        if whole
            return @jiri.createPattern("^#{partRegex}$").getRegex()
        else
            return @jiri.createPattern("\\b(#{partRegex})\\b").getRegex()

module.exports = Action
