Action = require './Action'
Pattern = require '../Pattern'

# Unknown Action, so Jiri can say "I don't understand" if directly addressed
# with an unknown command
#
# This won't be triggered if he's not addressed by name
class HelpAction extends Action

    # should return the class name as a string
    getType: ->
        return 'HelpAction'

    patternParts:
        "what_can_you_do": "(?=.*jiri.*)(jiri[,-—: ]*)?\\b(help|help with jiri|what (do|will|can) (you|I|we) do|what (can|does|will) jiri (do|understand)|what is jiri for?|what( i|\\')?s the (point|purpose) of jiri)\\?*([, ]+jiri\??)?$"
        "who_is_jiri": "^jiri[,:\\- ]* (what|who) are you\\??|(what|who)( i|')s (this )?jiri\\??"

    respondTo: (message) ->
        return new Promise (resolve, reject) =>
            text = []

            if message.text.match @jiri.createPattern('what_can_you_do', @patternParts).getRegex()
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

                resolve text: text.join "\n • "

            else if message.text.match @jiri.createPattern('who_is_jiri', @patternParts).getRegex()
                text = [
                    "I'm just a helpful little assistant.",
                    "A question I often ask myself",
                    "I can be whoever you want me to be. Unless you want me to be batman. I can't do batman.",
                ]
                resolve text: text[Math.floor(Math.random() * text.length)]

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        new Promise (resolve) =>
            pattern = @jiri.createPattern Object.keys(@patternParts).join('|'), @patternParts
            return resolve message.text.match pattern.getRegex()

module.exports = HelpAction
