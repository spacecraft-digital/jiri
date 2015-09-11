RSVP = require 'rsvp'
Action = require './Action'
Pattern = require '../Pattern'
mongoose = require '../../database_init'
Customer = mongoose.model 'Customer'
stringUtils = require '../utils/string'
humanize = require '../utils/humanize'
NaturalLanguageObjectReference = require '../NaturalLanguageObjectReference'
inflect = require('i')()
converter = require 'number-to-words'

# Query Customer database in natural language
#
class CustomerSetInfoAction extends Action

    # result was found — no follow up expected
    OUTCOME_CHANGED: 0
    # single suggestion — user can say 'yes'
    OUTCOME_SUGGESTION: 1
    # multiple suggestions — user can select by number
    OUTCOME_SUGGESTIONS: 2
    # invalid property
    OUTCOME_INVALID: 3
    # when no value is specified — prompt for it
    OUTCOME_NO_VALUE_SPECIFIED: 4

    patternParts:
        set: "(set|change|update|assign|edit|amend)(?:\\s+the)?"
        to: "(to|is|=|as)"

    # should return the class name as a string
    getType: ->
        return 'CustomerSetInfoAction'

    describe: ->
        return 'set information about customers\' projects'

    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>

            # remove detected URLs
            message.text = message.text.replace /<[^|>]+\|([^>]+)>/g, '$1'

            if @lastOutcome?.outcome is @OUTCOME_NO_VALUE_SPECIFIED
                query = @lastOutcome.data.query
                newValue = message.text.replace @jiri.createPattern('^jiri ').getRegex(), ''

            else
                matches = message.text.replace /(\w)['’]+s /g, '$1 '
                                    .match @getTestRegex()
                query = matches[1]
                arrayIndex = if matches[2] then parseInt matches[2], 10
                newValue = matches[3]

            ref = new NaturalLanguageObjectReference query
            ref.findTarget()
                .then (result) =>
                    lastMatch = result.matches[result.matches.length-1]

                    try
                        switch result.outcome
                            when NaturalLanguageObjectReference.prototype.RESULT_FOUND
                                targetPath = humanize.getRelationalPath result.matches

                                # Target found, but no new value specified
                                if typeof newValue is 'undefined'
                                    @jiri.recordOutcome @, @OUTCOME_NO_VALUE_SPECIFIED, query
                                    return resolve
                                        text: "What do you want to set _#{targetPath}_ to?"
                                        channel: @channel.id

                                parent = result.matches[result.matches.length-2].target
                                property = lastMatch.property

                                # Set array — requires an array index
                                if typeof result.target is 'object' and result.target.length?

                                    # Has array index — we can set the value
                                    if arrayIndex?

                                        # valid array index
                                        if result.target[arrayIndex]?
                                            targetPath = humanize.getRelationalPath result.matches, false
                                            return @setValue result.target, arrayIndex, newValue, targetPath, result.matches[0].target, resolve

                                        # out of range / invalid index
                                        else
                                            text = """There aren't #{converter.toWords arrayIndex+1} #{property}; there #{if result.target.length is 1 then 'is' else 'are'} only #{converter.toWords result.target.length}:
                                                    >>>
                                                    #{result.target.join "\n"}"""
                                            @jiri.recordOutcome @, @OUTCOME_INVALID

                                    # no array index — so give the user options to edit array members, or add a new one
                                    else
                                        options = []
                                        for child, i in result.target
                                            # scalar values can be set directly
                                            if typeof child in ['string','number', 'boolean']
                                                options.push
                                                    label: "`#{i+1}` Change `#{child}` to `#{newValue}`"
                                                    command: "set #{query}[#{i}] = #{newValue}"
                                            # objects will prompt for which property to change
                                            else
                                                childName = if child.getName then child.getName() else child
                                                optionLabels.push
                                                    label: "`#{i+1}` Edit #{childName}"
                                                    command: "set #{query} #{childName} = #{newValue}"

                                        options.push
                                            label: "`#{result.target.length+1}` Add a new #{inflect.singularize property}"
                                            command: "add \"#{newValue}\" to #{query}[]"

                                        # get ancestors for a path with all except the last
                                        ancestors = (r for r, i in result.matches when i < result.matches.length-1)
                                        text = "What do you want to do with _#{humanize.getRelationalPath ancestors} #{inflect.pluralize property}_?\n>>>\n#{(o.label for o in options).join "\n"}"

                                        @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, suggestions: (o.command for o in options)

                                # we can't assign a scalar value to an object, so we need to prompt for a slightly different action
                                # Either start to edit the object as a whole, or set a specific option
                                else if typeof result.target is 'object'
                                    o = if result.target.toObject then result.target.toObject() else result.target
                                    options = []
                                    index = 1
                                    for own p, v of o
                                        if typeof v is 'object'
                                            options.push "`#{index++}` Edit #{humanize._humanizeKey p}"
                                        else
                                            options.push "`#{index++}` Set #{humanize._humanizeKey p} to `#{newValue}`"
                                    text = "What do you want to do with _#{humanize.getRelationalPath result.matches}_?\n>>>\n#{options.join "\n"}"

                                else
                                    return @setValue parent, property, newValue, targetPath, result.matches[0].target, resolve

                            when NaturalLanguageObjectReference.prototype.RESULT_SUGGESTION
                                if result.suggestions.length is 1
                                    @jiri.recordOutcome @, @OUTCOME_SUGGESTION, {suggestion: result.suggestions[0], newValue: newValue}
                                    text = "Did you mean “#{result.formattedSuggestions[0]}”?"
                                else
                                    @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, {suggestions: result.suggestions, newValue: newValue}
                                    result.formattedSuggestions = result.formattedSuggestions.map (r, i) -> "`#{i+1}` #{r}"
                                    text = "Did you mean one of these?\n>>>\n#{result.formattedSuggestions.join "\n"}"

                            when NaturalLanguageObjectReference.prototype.RESULT_UNKNOWN
                                bits = humanize.explainMatches result.matches
                                text = "I understood that #{stringUtils.join bits}, but I'm not sure I get the `#{lastMatch.query}` bit.\n\nCould you try rephrasing it?"
                                @jiri.recordOutcome @, @OUTCOME_INVALID

                    text = "Sorry, I'm not able to decipher `#{query}`. Try rephrasing?" unless text

                    return resolve
                        text: text
                        channel: @channel.id
                        unfurl_links: false

                .catch (error) =>
                    return resolve
                        text: error
                        channel: @channel.id

    # Sets a value and saves the customer
    #
    # Parameters:
    #   parent[property] will be set to value
    #   targetPath will be used in the message to the customer
    #   customer is the Customer object that parent is a descendent of
    #   resolve is the Promise callback
    setValue: (parent, property, value, targetPath, customer, resolve) ->

        # allow boolean values to be set with a variety of text strings
        if typeof parent[property] is 'boolean' and typeof value != 'boolean'
            switch value.toLowerCase()
                when 'yes','y', 'true' then value = true
                when 'no', 'n', 'false' then value = false
                else throw "Could not convert `#{value}` to a boolean"

        previousValue = parent[property]
        parent[property] = value
        @jiri.recordOutcome @, @OUTCOME_CHANGED

        if typeof parent is 'object' and parent.length?
            saveMessage = "The #{converter.toWordsOrdinal arrayIndex+1} of _#{targetPath}_ is now `#{newValue}`\n(it was `#{previousValue}`)"
        else
            saveMessage = "_#{targetPath}_ is now `#{value}`\n(it was `#{previousValue}`)"

        return customer.save()
                .then (customer) =>
                    return resolve
                        text: saveMessage
                        channel: @channel.id
                        unfurl_links: false

    getTestRegex: =>
        unless @pattern
            @pattern = @jiri.createPattern '^jiri set\\s+(.+?)(?:\\[(\\d+)\\])?(?:\\s+to\\s+[\'"“‘`<_]?(.+?)[>\'"”’`_]?)?$', @patternParts
        return @pattern.getRegex()

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) =>
        @lastOutcome = @jiri.getLastOutcome @
        if @lastOutcome?.outcome is @OUTCOME_NO_VALUE_SPECIFIED
            if message.text.match @jiri.createPattern('^jiri (["\'“‘].+["\'“‘]$|[\\S]+$)').getRegex()
                return true
            # avoid treating a new command as a value
            else
                delete @lastOutcome
        return message.text.match @getTestRegex()

module.exports = CustomerSetInfoAction
