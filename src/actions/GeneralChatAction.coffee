RSVP = require 'rsvp'
Action = require './Action'
Pattern = require '../Pattern'

# General chit chat. In case you're in need of a friend.
#
class GeneralChatAction extends Action

    constructor: (@jiri, @channel) ->

    patternParts:
        hello: "^(?=.*jiri.*)(jiri[,-—: ]*)?\\b(are you there\\??|hi|hello|hey|yo|s\\'?up|what\\'?s up|greetings|oi)\\b.*"

    # should return the class name as a string
    getType: ->
        return 'GeneralChatAction'

    describe: ->
        return 'make some small talk, if you\'re really bored'

    respondTo: (message) ->
        userName = message.user.profile.first_name || message.user.profile.real_name || message.user.name;

        return new RSVP.Promise (resolve, reject) =>
            if message.subtype in ['group_join', 'channel_join']
                text = [
                    "Hi folks",
                    "Jiri, at your service.",
                    "Never fear, Jiri is here",
                    "Hi. Thanks for having me",
                    "Hey everyone. How are we all?",
                    "Hello!",
                    "Jiri is in da house",
                    "Let's get Jiri with it",
                ]
                hours = new Date().getHours()
                if hours < 12
                    text.push "Good morning!"
                    text.push "Top of the morning to you all"
                else if hours > 17
                    text.push "Good evening"
                    text.push "Evenin'"
                else
                    text.push "Good afternoon"

            else
                pattern = @jiri.createPattern '', @patternParts

                pattern.metaPattern = 'hello'

                if message.text||''.match pattern.getRegex()
                    text = [
                        "Why hello there",
                        "Hi #{userName}, how're you doing?",
                        "S'up #{userName}",
                        "Yo yo",
                        "Hey #{userName}, how can I help?",
                        "You rang?",
                    ]
                    hours = new Date().getHours()
                    if hours < 12
                        text.push "Morning!"
                        text.push "Top of the morning to you"
                    else if hours > 17
                        text.push "Good evening"
                        text.push "Evenin'"
                    else
                        if message.channel.is_im
                            text.push "Good afternoon"
                        else
                            text.push "Good afternoon everybody"
                            text.push "Good afternoon"

            resolve
                text: text[Math.floor(Math.random() * text.length)]
                channel: @channel.id

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) =>
        return true if message.subtype in ['group_join', 'channel_join']

        return false unless message.text

        pattern = @jiri.createPattern 'hello', @patternParts
        return message.text.match pattern.getRegex()

module.exports = GeneralChatAction
