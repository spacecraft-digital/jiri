Action = require './Action'
Pattern = require '../Pattern'
config = require '../../config'
moment = require 'moment'

# General chit chat. In case you're in need of a friend.
#
class GeneralChatAction extends Action

    patternParts:
        hello: "^(?=.*jiri).*\\b(say (hello|hi)( to the (nice )?people)?|where are you|are you there\\??|hi|hello|hey|yo|s\\'?up|what\\'?s up|greetings|oi)\\b.*"
        thanks: "^(?=.*jiri).*\\b(thank you( very much)?|thanks|ta|cheers|nice one|good work|ta muchly)\\b.*"
        stupid: "^(?=.*jiri).*\\b(stupid|drunk|annoying|go away|get lost|fuck off|piss off)\\b.*"

    # should return the class name as a string
    getType: ->
        return 'GeneralChatAction'

    describe: ->
        return 'make some small talk, if you\'re really bored'

    respondTo: (message) ->
        userName = message.user.profile.first_name || message.user.profile.real_name || message.user.name;

        hours = moment.tz(config.timezone).hours()

        return new Promise (resolve, reject) =>
            if message.subtype in ['group_join', 'channel_join'] and message.user.id is @jiri.slack.self.id
                text = [
                    "Hi folks",
                    "Jiri, at your service.",
                    "Never fear, Jiri is here",
                    "Hi. Thanks for having me",
                    "Hey everyone. How are we all?",
                    "Hello!",
                    "Jiri is in da house",
                    "Let's get Jiri with it",
                    ":wave:",
                ]
                if hours < 12
                    text.push "Good morning!"
                    text.push "Top of the morning to you all"
                else if hours > 17
                    text.push "Good evening"
                    text.push "Evenin'"
                else
                    text.push "Good afternoon"

            else if message.text.match @jiri.createPattern('hello', @patternParts).getRegex()
                text = [
                    "Why hello there",
                    "Hi #{userName}, how're you doing?",
                    "S'up #{userName}",
                    "Yo yo",
                    "Hey #{userName}, how can I help?",
                    "You rang?",
                ]
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

            else if message.text.match @jiri.createPattern('thanks', @patternParts).getRegex()
                text = [
                    "You're welcome, #{userName}",
                    "Any time, #{userName}",
                    "Any time",
                    "At your service, #{userName}",
                    "Your wish is my command",
                    "Don't mention it, #{userName}",
                    "My pleasure",
                    "There's nothing I'd rather be doing.",
                    "No problem. ",
                    "No problem. Let me know if there's anything else I can help with.",
                    ":grin:"
                ]

            else if message.text.match @jiri.createPattern('stupid', @patternParts).getRegex()
                pkg = require "../../package.json"
                text = [
                    "Give me a chance, #{userName} — I'm still young",
                    "Merge requests welcome: #{pkg.repository}",
                    "`/kick @jiri`…?",
                ]


            if text.length
                resolve text: text[Math.floor(Math.random() * text.length)]

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        new Promise (resolve) =>
            return resolve true if message.subtype in ['group_join', 'channel_join'] and message.user.id is @jiri.slack.self.id

            return resolve false unless message.text

            pattern = @jiri.createPattern Object.keys(@patternParts).join('|'), @patternParts
            return resolve message.text.match pattern.getRegex()

module.exports = GeneralChatAction
