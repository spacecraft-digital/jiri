RSVP = require 'rsvp'
Action = require './Action'
Pattern = require '../Pattern'
mongoose = require '../../database_init'
Customer = mongoose.model 'Customer'
stringUtils = require '../utils/string'
humanize = require '../utils/humanize'
NaturalLanguageObjectReference = require '../NaturalLanguageObjectReference'
inflect = require '../utils/inflect'
converter = require 'number-to-words'

# Modify Customer database in natural language
#
# Add, edit, remove properties
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

    MODE_NEW: 0
    MODE_SET_VALUE: 1
    MODE_CANCEL: 2
    MODE_USE_SUGGESTION: 3

    patternParts:
        set: "(add|append|set|change|update|assign|edit|amend|remove|delete|drop|empty|truncate|clear)(?:\\s+the)?"
        _to: "(to|is|=|as)"
        yes: "jiri y(es|ep|up)?\\s*(please|thanks|thank you|cheers|mate)?"
        no: "jiri (n|no|nope|nah)( (thanks|thank you|cheers))?"
        numberChoice: "jiri (\\d+)\\s*(please|thanks|thank you|cheers)?"

    # these need to include all the verbs in @patternParts.set
    verbSynonyms:
        set: ['set', 'change', 'update', 'assign', 'edit', 'amend']
        add: ['add', 'append']
        remove: ['remove', 'delete', 'drop']
        empty: ['empty', 'truncate', 'clear']

    # should return the class name as a string
    getType: ->
        return 'CustomerSetInfoAction'

    describe: ->
        return 'set information about customers\' projects'

    respond: (text) =>
        throw new Error "No resolve callback set" unless @responseResolveCallback
        return @responseResolveCallback
            text: text
            channel: @channel.id
            unfurl_links: false

    respondWithError: (text) =>
        throw new Error "No reject callback set" unless @responseRejectCallback
        return @responseRejectCallback text

    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            @responseResolveCallback = resolve
            @responseRejectCallback = reject

            # remove detected URLs
            message.text = message.text.replace /<[^|>]+\|([^>]+)>/g, '$1'

            # load suggestion as message text
            if @mode is @MODE_USE_SUGGESTION
                if @lastOutcome?.outcome is @OUTCOME_SUGGESTIONS
                    m = message.text.match @getRegex('numberChoice')
                    index = parseInt(m[1], 10)-1 if m
                    if index? and @lastOutcome.data.suggestions[index]
                        message.text = "jiri #{@lastOutcome.data.suggestions[index]}"
                    else
                        return @respond "That wasn't one of the options!"

                else if @lastOutcome?.outcome is @OUTCOME_SUGGESTION
                    if message.text.match @getRegex('yes')
                        message.text = "jiri #{@lastOutcome.data.suggestion}"
                    else
                        @mode = @MODE_CANCEL

            if @mode is @MODE_CANCEL
                @jiri.recordOutcome @
                return @respond "_(nothing changed)_"

            if @mode is @MODE_SET_VALUE
                query = @lastOutcome.data.query
                arrayIndex = @lastOutcome.data.arrayIndex
                verb = @lastOutcome.data.verb
                newValue = message.text.replace @jiri.createPattern('^jiri ').getRegex(), ''

            else
                matches = message.text.replace /(\w)['’]+s /g, '$1 '
                                    .match @getTestRegex()

                m = message.text.match @jiri.createPattern('^jiri set', @patternParts, true).getRegex()
                verb = if m then m[2] else 'set'

                query = matches[2]
                arrayIndex = if matches[3] then parseInt matches[3], 10

                console.log
                    verb: verb
                    query: query
                    newValue: newValue
                console.log @getTestRegex()

                # set Foo to "bar"
                if verb in @verbSynonyms.set or verb in @verbSynonyms.add
                    newValue = matches[4]
                # add (value) "bar" to (array) Foo
                # add (array) Bar to (object) Foo (via a subrequest)
                # else if verb in @verbSynonyms.add
                #     newValue = matches[1]
                # convert 'remove bar from Foo' -> 'remove Foo bar'
                else if matches[1] and verb in @verbSynonyms.remove
                    query += " #{matches[1]}"
                # remove Foo to "bar"
                else if matches[4] and verb in @verbSynonyms.remove
                    return @respond "Sorry, your request doesn't make sense to me:\n>>>#{verb} #{query}"


            # trim quote marks
            newValue = newValue.replace(/(^['"“‘`]|['"”’`]$)/g, '').trim() if newValue

            @setLoading()
            @parseQuery verb.toLowerCase(), query, arrayIndex, newValue

    parseQuery: (verb, query, arrayIndex, newValue) =>

        # add customer (with flag to skip search for existing customers with the same name)
        if verb in @verbSynonyms.add and m = query.match /^(?:new )?customers?\b(?: +(.+?)?( --ignoreExisting)?)?$/i
            return @addCustomer newValue or m[1], !!m[2]

        @setLoading()
        ref = new NaturalLanguageObjectReference query
        ref.findTarget()
            .then (result) => @doVerbToTarget verb, query, arrayIndex, newValue, result
            .catch (error) => @respond error

    doVerbToTarget: (verb, query, arrayIndex, newValue, result) =>
        try
            switch result.outcome
                when NaturalLanguageObjectReference.prototype.RESULT_FOUND

                    property = result.matches[result.matches.length-1].property

                    # ARRAY
                    if typeof result.target is 'object' and result.target.length?
                        # catch out of range / invalid index
                        if arrayIndex? and not result.target[arrayIndex]?
                            return @respondOutOfRange property, arrayIndex, result.target

                        # add to array
                        if verb in @verbSynonyms.add
                            return @addToArray query, newValue, result
                        # set array
                        else if verb in @verbSynonyms.set
                            return @setArray query, arrayIndex, newValue, result
                        # remove from array
                        else if verb in @verbSynonyms.remove
                            return @removeFromArray query, arrayIndex, result
                        else
                            return @respondWithError "I don't understand how to #{verb} an array"

                    # OBJECT
                    else if typeof result.target is 'object'

                        if verb in @verbSynonyms.set
                            return @setObject query, newValue, result
                        # handle “add Foo to Bar” form, where Foo is an array property of object Bar
                        else if verb in @verbSynonyms.add and result.target[newValue]?
                            return @parseQuery verb, "#{query} #{newValue}", arrayIndex, null
                        # else if verb in @verbSynonyms.add and result.matches[result.matches.length-2].target[inflect.pluralize property]?
                        #     return @parseQuery verb, query.replace(new RegExp("\\b#{property}\\b"), pluralize property), arrayIndex, newValue

                        # can't add or remove an object
                        else
                            return @respondWithError "I don't understand how to #{verb} an object"

                    else
                        if verb in @verbSynonyms.set or verb in @verbSynonyms.add
                            return @setScalar query, newValue, result
                        # can't add or remove an object
                        else
                            return @respondWithError "I don't understand how to #{verb} a scalar value"

                when NaturalLanguageObjectReference.prototype.RESULT_SUGGESTION
                    result.suggestions = result.suggestions.map (r) -> "set #{r}"

                    if result.suggestions.length is 1
                        @jiri.recordOutcome @, @OUTCOME_SUGGESTION, {suggestion: result.suggestions[0], newValue: newValue}
                        text = "Did you mean “#{result.formattedSuggestions[0]}”?"
                    else
                        @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, {suggestions: result.suggestions, newValue: newValue}
                        result.formattedSuggestions = result.formattedSuggestions.map (r, i) -> "`#{i+1}` #{r}"
                        text = "Did you mean one of these?\n>>>\n#{result.formattedSuggestions.join "\n"}"

                when NaturalLanguageObjectReference.prototype.RESULT_UNKNOWN
                    bits = humanize.explainMatches result.matches
                    lastMatch = result.matches[result.matches.length-1]
                    text = "I understood that #{stringUtils.join bits}, but I'm not sure I get the `#{lastMatch.query}` bit.\n\nCould you try rephrasing it?"
                    @jiri.recordOutcome @, @OUTCOME_INVALID

            text = "Sorry, I'm not able to decipher `#{verb} #{query}`. Try rephrasing?" unless text
        catch e
            console.log e.stack
            text = "I should be able to do that, but I'm not feeling at all well today. (That's an error, by the way)"

        return @respond text

    formatValueForDisplay: (value) -> if value then "`#{@jiri.slack.escape(value)}`" else '_empty_'

    promptForValue: (query, arrayIndex, verb, targetPath) =>
        @jiri.recordOutcome @, @OUTCOME_NO_VALUE_SPECIFIED, {query: query, arrayIndex: arrayIndex, verb: verb}
        if arrayIndex?
            text = "What do you want to change the #{converter.toWordsOrdinal arrayIndex+1} of _#{targetPath}_ to?\n(or type `cancel`)"
        else
            text = "What do you want to change _#{targetPath}_ to?\n(or type `cancel`)"
        return @respond text

    respondOutOfRange: (property, arrayIndex, array) ->
        @jiri.recordOutcome @, @OUTCOME_INVALID
        return @respond """There aren't #{converter.toWords arrayIndex+1} #{property}; there #{if array.length is 1 then 'is' else 'are'} only #{converter.toWords array.length}:
                ```#{array.join "\n"}```"""

    setArray: (query, arrayIndex, newValue, result) ->
        parent = result.matches[result.matches.length-2].target
        property = result.matches[result.matches.length-1].property

        # Targetting a specific array index
        if arrayIndex?

            # get target path without count
            targetPath = humanize.getRelationalPath result.matches, false

            # Target found, but no new value specified
            if typeof newValue is 'undefined'
                return @promptForValue query, arrayIndex, 'set', targetPath
            else
                return @setArrayValue parent, property, arrayIndex, newValue, targetPath, result.matches[0].target

        # user asked to 'set' whole array, which is an invalid operation. Need to be more specific
        else
            options = []
            if newValue
                for child, i in result.target
                    # scalar values can be set directly
                    if typeof child in ['string','number', 'boolean']
                        options.push
                            label: "`#{i+1}` Change `#{child}` to #{@formatValueForDisplay newValue}"
                            command: "set #{query}[#{i}] = #{newValue}"
                    # objects will prompt for which property to change
                    else
                        childName = if child.getName then child.getName() else child
                        options.push
                            label: "`#{i+1}` Edit #{childName}"
                            command: "set #{query} #{childName} = #{newValue}"
                options.push
                    label: "`#{result.target.length+1}` Add a new #{inflect.singularize property}"
                    command: "add \"#{newValue}\" to #{query}"

            else
                for child, i in result.target
                    # scalar values can be set directly
                    if typeof child in ['string','number', 'boolean']
                        options.push
                            label: "`#{i+1}` Change `#{child}`"
                            command: "set #{query}[#{i}]"
                    # objects will prompt for which property to change
                    else
                        childName = if child.getName then child.getName() else child
                        options.push
                            label: "`#{i+1}` Edit #{childName}"
                            command: "set #{query} #{childName}"
                options.push
                    label: "`#{result.target.length+1}` Add a new #{inflect.singularize property}"
                    command: "add #{query}"

            # get ancestors for a path with all except the last
            ancestors = (r for r, i in result.matches when i < result.matches.length-1)
            text = "What do you want to do with _#{humanize.getRelationalPath ancestors} #{inflect.pluralize property}_?\n>>>\n#{(o.label for o in options).join "\n"}"

            @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, suggestions: (o.command for o in options)

            return @respond text

    addToArray: (query, newValue, result) ->
        targetPath = humanize.getRelationalPath result.matches, false, true
        parent = result.matches[result.matches.length-2].target
        property = result.matches[result.matches.length-1].property
        array = result.target
        customer = result.matches[0].target

        if newValue?
            return @addArrayValue parent, property, newValue, targetPath, customer
        else
            @jiri.recordOutcome @, @OUTCOME_NO_VALUE_SPECIFIED, {query: query, verb: 'add'}
            if array.length is 0
                text = "_#{targetPath}_ is currently an empty list\n"
            else if array.length <= 3
                text = "_#{targetPath}_ are currently: \n```#{stringUtils.join array}```\n"
            else
                text = "_#{targetPath}_ are currently: \n```#{stringUtils.join array.slice(0,3)}```\n(and #{array.length - 3} more)\n"

            text += "*What do you want to add?* (type `nothing` to cancel)"

            return @respond text

    removeFromArray: (query, arrayIndex, result) ->
        if arrayIndex?
            parent = result.matches[result.matches.length-2].target
            property = result.matches[result.matches.length-1].property
            previousValue = result.target[arrayIndex]
            customer = result.matches[0].target

            parent[property] = parent[property].splice arrayIndex, 1
            saveMessage = "I've removed #{@formatValueForDisplay previousValue} from _#{humanize.getRelationalPath result.matches, false, true}_"

            @setLoading()
            return customer.save().then (customer) =>
                return @respond saveMessage

        else
            options = []
            for child, i in result.target
                options.push
                    label: "`#{i+1}` #{child}"
                    command: "remove #{query}[#{i}]"

            @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, suggestions: (o.command for o in options)
            # get ancestors for a path with all except the last
            text = "Which of _#{humanize.getRelationalPath result.matches, false, true}_ do you want to remove?\n>>>\n#{(o.label for o in options).join "\n"}"

        return @respond text

    # we can't assign a scalar value to an object, so we need to prompt for a slightly different action
    # Either start to edit the object as a whole, or set a specific option
    setObject: (query, newValue, result) ->
        unless newValue?
            targetPath = humanize.getRelationalPath result.matches, true, true
            return @promptForValue query, null, 'set', targetPath

        o = if result.target.toObject then result.target.toObject() else result.target

        options = []
        index = 1
        for own p, v of o
            if typeof v is 'object'
                options.push "`#{index++}` Edit #{humanize._humanizeKey p}"
            else
                options.push "`#{index++}` Set #{humanize._humanizeKey p} to #{@formatValueForDisplay newValue}"

        text = "What do you want to do with _#{humanize.getRelationalPath result.matches}_?\n>>>\n#{options.join "\n"}"

        return @respond text

    setScalar: (query, newValue, result) ->
        targetPath = humanize.getRelationalPath result.matches, true

        unless newValue?
            return @promptForValue query, null, 'set', targetPath

        parent = result.matches[result.matches.length-2].target
        property = result.matches[result.matches.length-1].property
        customer = result.matches[0].target

        return @setValue parent, property, newValue, targetPath, customer


    # Sets a scalar value and saves the customer
    #
    # Parameters:
    #   parent[property] will be set to value
    #   targetPath will be used in the message to the customer
    #   customer is the Customer object that parent is a descendent of
    #
    setValue: (parent, property, value, targetPath, customer) ->

        # allow boolean values to be set with a variety of text strings
        if typeof parent[property] is 'boolean' and typeof value != 'boolean'
            switch value.toLowerCase()
                when 'yes','y', 'true' then value = true
                when 'no', 'n', 'false' then value = false
                else throw "Could not convert `#{value}` to a boolean"

        previousValue = parent[property]

        if value is previousValue
            @jiri.recordOutcome @
            return @respond "_#{targetPath}_ is already set to #{@formatValueForDisplay value}"

        @jiri.recordOutcome @, @OUTCOME_CHANGED

        parent[property] = value
        saveMessage = "_#{targetPath}_ is now #{@formatValueForDisplay value}\n(it was #{@formatValueForDisplay previousValue})"

        @setLoading()
        return customer.save().then (customer) => @respond saveMessage

    setArrayValue: (parent, property, arrayIndex, value, targetPath, customer) ->

        targetText = "The #{converter.toWordsOrdinal arrayIndex+1} of _#{targetPath}_"

        throw new Error "Invalid array index #{arrayIndex}" unless parent[property][arrayIndex]?

        previousValue = parent[property][arrayIndex]
        if value is previousValue
            @jiri.recordOutcome @
            return @respond "#{targetText} is already set to #{@formatValueForDisplay value}"

        @jiri.recordOutcome @, @OUTCOME_CHANGED

        array = parent[property]
        array[arrayIndex] = value
        parent[property] = array

        saveMessage = "#{targetText} is now #{@formatValueForDisplay value}\n(it was #{@formatValueForDisplay previousValue})"

        @setLoading()
        return customer.save().then (customer) => @respond saveMessage

    addArrayValue: (parent, property, value, targetPath, customer) ->

        @jiri.recordOutcome @, @OUTCOME_CHANGED

        parent[property].push value
        saveMessage = "I've added #{@formatValueForDisplay value} to #{targetPath}"

        @setLoading()
        return customer.save().then => @respond saveMessage


    addCustomer: (name, ignoreExisting = false) ->
        new RSVP.Promise (resolve, reject) =>
            unless name?
                @jiri.recordOutcome @, @OUTCOME_NO_VALUE_SPECIFIED, query: 'customer', verb: 'add'
                return @respond "What's the name of the customer to add? (type `cancel` to cancel)"

            if ignoreExisting
                promise = new RSVP.Promise (resolve) -> resolve()
            else
                @setLoading()
                promise = Customer.findOneByName name
                .then (customer) =>
                    if customer
                        new RSVP.Promise (resolve, reject) =>
                            @jiri.recordOutcome @, @OUTCOME_SUGGESTION, suggestion: "add customer #{name} --ignoreExisting"
                            text = "There's already a customer called `#{customer.name}`"
                            if customer.aliases?.length
                                text += "\n_(AKA #{customer.aliases.join ', '})_"
                            text += "\n\n*Are you sure you want to add a new customer called* `#{name}` *?*"
                            @respond text
                            return customer
                    else
                        console.log "No existing customers matching #{name}"

            promise.then (customer) =>
                return if customer
                @setLoading()
                @jiri.recordOutcome @
                customer = new Customer name: name
                customer.save()
                    .then (customer) =>
                        return @respond "Sorted. Ladies and gentlemen, allow me to introduce… `#{customer.name}` :tada:"
                    .catch (error) =>
                        return @respondWithError error

    getTestRegex: =>
        unless @pattern
            valueRegex = '[\'"“‘`<_]?(.+?)[>\'"”’`_]?'
            @pattern = @jiri.createPattern "^jiri set (?:#{valueRegex} (?:to|from) )??(.+?)(?:\\[(\\d+)\\])?(?: _to #{valueRegex})?$", @patternParts
        return @pattern.getRegex()

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        new RSVP.Promise (resolve) =>
            mainRegexMatch = message.text.match @getTestRegex()
            cancelCommand = message.text.match(@jiri.createPattern('^jiri (cancel|undo|stop|ignore|nothing)').getRegex())
            @lastOutcome = @jiri.getLastOutcome @
            if @lastOutcome?.outcome is @OUTCOME_NO_VALUE_SPECIFIED
                @mode = if mainRegexMatch or cancelCommand then @MODE_CANCEL else @MODE_SET_VALUE
                return resolve true
            if (@lastOutcome?.outcome is @OUTCOME_SUGGESTIONS and message.text.match @getRegex('numberChoice')) or
               (@lastOutcome?.outcome is @OUTCOME_SUGGESTION and message.text.match @getRegex('yes'))
                @mode = @MODE_USE_SUGGESTION
                return resolve true
            if @lastOutcome?.outcome in [@OUTCOME_SUGGESTIONS, @OUTCOME_SUGGESTION] and (cancelCommand or message.text.match(@getRegex('no')))
                @mode = @MODE_CANCEL
                return resolve true

            @mode = @MODE_NEW
            return resolve mainRegexMatch

module.exports = CustomerSetInfoAction
