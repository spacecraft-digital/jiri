RSVP = require 'rsvp'
Action = require './Action'
Pattern = require '../Pattern'

# Unknown Action, so Jiri can say "I don't understand" if directly addressed
# with an unknown command
#
# This won't be triggered if he's not addressed by name
class UnknownAction extends Action

    constructor: (@jiri, @channel) ->

    # should return the class name as a string
    getType: ->
        return 'UnknownAction'

    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            delete message._client
            delete message.user._client
            console.log "I don't understand this:\n",
                type: message.type,
                subtype: message.subtype,
                channelName: message.channelName,
                userName: message.userName,
                text: message.text,

            text = [
                "Sorry, I don't understand",
                "I don't follow",
                "I'm not sure what you mean",
                "You'll have to rephrase that, I'm not very smart.",
                "Apologies, but I have no idea what you're talking about",
                "Je ne comprends pas",
                "?",
                "¯\\_(ツ)_/¯",
            ]
            # is a question
            if message.text.match /\?$/
                text.push "Good question. No idea, I'm afraid."
            else
                text.push "Good point, well made."
                text.push "That's an interesting perspective. Although not one I have anything to input on."

            resolve
                text: text[Math.floor(Math.random() * text.length)]
                channel: @channel.id

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) =>
        return false unless message.type is 'message' and message.text? and message.channel?

        return false if message.subtype is 'bot_message'

        # this is only if nothing else has responded
        return false unless @jiri.matchingActions is 0

        return true if @channel.is_im

        pattern = @jiri.createPattern '^jiri\\b.+'
        return message.text.match pattern.getRegex()

module.exports = UnknownAction
