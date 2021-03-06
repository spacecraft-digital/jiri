uncamelize = require 'uncamelize'
Action = require './Action'
Pattern = require '../Pattern'
CustomerInfoAction = require './CustomerInfoAction'
CustomerSetInfoAction = require './CustomerSetInfoAction'

# Unknown Action, so Jiri can say "I don't understand" if directly addressed
# with an unknown command
#
# This won't be triggered if he's not addressed by name
class UnknownAction extends Action

    @OUTCOME_SUGGESTION: 1

    # should return the class name as a string
    getType: ->
        return 'UnknownAction'

    respondTo: (message) ->
        Customer = @customer_database.model 'Customer'
        Project = @customer_database.model 'Project'
        Repository = @customer_database.model 'Repository'
        Stage = @customer_database.model 'Stage'

        return new Promise (resolve, reject) =>
            resolve @jiri.getLastOutcome @

        .then (lastOutcome) =>
            @lastOutcome = lastOutcome
            # if a suggestion has been accepted, pipe that message back to the start of the response process so other Actions can respond
            if @lastOutcome and @lastOutcome.outcome is @OUTCOME_SUGGESTION and message.text.match @jiri.createPattern("^jiri yes$", CustomerSetInfoAction.patternParts).getRegex()
                message.text = @lastOutcome.data.query
                return @jiri.actOnMessage message

            # gather a list of entity properties, to help identify the end of the string supposed to be a customer name
            properties = []
            for model in [Customer, Project, Repository, Stage]
                for property in Object.keys(model.schema.paths).concat(Object.keys(model.schema.virtuals))
                    properties.push property if properties.indexOf(property) is -1
                    uncamelizedProperty = uncamelize property
                    properties.push uncamelizedProperty if properties.indexOf(uncamelizedProperty) is -1

            regexes = [
                @jiri.createPattern("^jiri (find .+? for (.+?)\\b)",
                        find: CustomerInfoAction.prototype.patternParts.find
                    ).getRegex(),
                @jiri.createPattern("^jiri ((?:find|set) (.+?)(?: +(#{properties.join('|')})\\b.*)?$)",
                        find: CustomerInfoAction.prototype.patternParts.find
                        set: CustomerSetInfoAction.prototype.patternParts.set
                    ).getRegex(),
            ]

            for regex in regexes
                if m = message.text.match regex
                    query = m[1]
                    customerName = m[2]
                    return Customer.fuzzyFindOneByName(customerName).then (customer) =>
                        if customer
                            query = query.replace(new RegExp(customerName), customer.name)
                            @jiri.recordOutcome @, @OUTCOME_SUGGESTION, {query: query}
                            return text: "Did you mean `#{query}`?"

            # no idea what the message means
            @jiri.recordOutcome @
            delete message._client
            delete message.user._client
            console.log "I don't understand this #{((message.subtype or '') + ' ' + message.type).trim()} from #{message.userName} in #{message.channelName}\n  #{message.text}"

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

            return text: text[Math.floor(Math.random() * text.length)]

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        Promise.resolve false unless message.type is 'message' and message.text? and message.channel?

        Promise.resolve false if message.subtype is 'bot_message'

        Promise.resolve true if @channel.is_im

        pattern = @jiri.createPattern 'jiri\\b([ ?.!,:]|$)'
        dontMatch = @jiri.createPattern '(will|wo|is|does|has)(n\'?t)? jiri'
        if message.text.match(pattern.getRegex()) and not message.text.match(dontMatch.getRegex())
            Promise.resolve true

        Promise.resolve false

module.exports = UnknownAction
