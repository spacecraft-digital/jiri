RSVP = require 'rsvp'
Action = require './Action'
Pattern = require '../Pattern'

# Unknown Action, so Jiri can say "I don't understand" if directly addressed
# with an unknown command
#
# This won't be triggered if he's not addressed by name
class HelpAction extends Action

    constructor: (@jiri, @channel) ->

    # should return the class name as a string
    getType: ->
        return 'HelpAction'

    patternParts:
        "what_can_you_do": "(?=.*jiri.*)(jiri[,-—: ]*)?\\b(help|help with jiri|what (do|will|can) (you|I|we) do|what (can|does|will) jiri (do|understand)|what is jiri for?|what( i|\\')?s the (point|purpose) of jiri)\\?*([, ]+jiri\??)?$"

    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            text = []

            ledes = [
                "*Here's what I can do:*",
                "*I can do stuff like this…*",
                "*I'm glad you asked. I can…*",
                "*Thanks for asking. I can…*",
                "*I can…*",
                "*You wanna know what floats my boat? I like to…*",
                "*On a good day, I can:*"
            ]
            text.push ledes[Math.floor(Math.random() * ledes.length)]

            # allow each Action to describe itself
            for actionClass in @jiri.actions
                action = new actionClass @, message.channel
                description = action.describe()
                text.push description unless description in ['', undefined]

            resolve
                text: text.join "\n • "
                channel: @channel.id

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) =>
        pattern = @jiri.createPattern 'what_can_you_do', @patternParts
        return message.text.match pattern.getRegex()

module.exports = HelpAction
