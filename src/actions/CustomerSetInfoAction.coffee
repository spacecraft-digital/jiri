Action = require './Action'
Pattern = require '../Pattern'
humanize = require '../utils/humanize'
inflect = require '../utils/inflect'
converter = require 'number-to-words'
moment = require 'moment'
uncamelize = require 'uncamelize'
joinn = require 'joinn'

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
        remove: ['unset', 'remove', 'delete', 'drop']
        empty: ['empty', 'truncate', 'clear']

    # should return the class name as a string
    getType: ->
        return 'CustomerSetInfoAction'

    describe: ->
        return 'record information about customers\' projects'

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
        return new Promise (resolve, reject) =>
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

                # set Foo to "bar"
                if verb in @verbSynonyms.set
                    newValue = matches[4]
                # add (value) "bar" to (array) Foo
                # add (array) Bar to (object) Foo (via a subrequest)
                else if verb in @verbSynonyms.add and matches[1]
                    # add "bar" to Foo (with quote marks -> treat bar as a value)
                    if matches[1].match /^['"“‘`].*['"”’`]$/
                        newValue = matches[1]
                    # add bar to Foo (assume bar is an array property of Foo)
                    else
                        # flag that we're treated it as a “split query”
                        @assumedSplitAddQuery =
                            query: query
                            newValue: matches[1]
                        query += " #{matches[1]}"
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

        # convert redundant 'add to' -> 'add'
        query = query.replace /^to +/i, '' if verb in @verbSynonyms.add

        @setLoading()
        Customer = @customer_database.model 'Customer'
        Customer.resolveNaturalLanguage query
            .then (result) => @doVerbToTarget verb, query, arrayIndex, newValue, result
            .catch (error) => @respond error

    getObjectType: (object) ->
        m = {}.toString.call(object).match(/^\[object (.+)\]$/)
        return if m then m[1] else 'Object'

    doVerbToTarget: (verb, query, arrayIndex, newValue, result) =>
        try
            lastMatch = result.matches[result.matches.length-1]

            switch result.outcome
                when 'found'

                    parent = result.matches[result.matches.length-2]?.target
                    property = lastMatch.property

                    # For aliases, we'll switch to the 'real' property,
                    # assuming the Mongoose virtuals specifies a _jiri_aliasTarget option
                    if parent?.schema?.virtuals[property]
                        aliasedProperty = parent?.schema?.virtuals[property]?.options?._jiri_aliasTarget
                        return @respond "I'm afraid you can't set `#{property}`. That's just the way it is for now." unless aliasedProperty
                        @switchTarget result, aliasedProperty
                        query = query.replace new RegExp("\\b#{property}\\b"), aliasedProperty
                        console.log "Silently switching #{property} to #{aliasedProperty}" if @jiri.debugMode
                        property = aliasedProperty

                    if parent?.schema?.paths[property]?.instance
                        propertyType = parent.schema?.paths[property]?.instance

                    else if typeof result.target is 'object'
                        propertyType = @getObjectType result.target

                    else if typeof result.target is 'undefined'
                        propertyType = 'undefined'

                    else
                        propertyType = typeof result.target

                    # ARRAY
                    if propertyType is 'Array'
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

                    # DATE
                    else if propertyType is 'Date'
                        if verb in @verbSynonyms.set or verb in @verbSynonyms.add
                            if newValue?
                                date = moment(new Date newValue)
                                unless date.isValid()
                                    # by not recording a new outcome, the user should be able to enter the date again
                                    return @respond "Sorry, I'm not sure how to understand `#{newValue}` as a date. It's best to enter it as YYYY-MM-DD. Try again if you like:"
                                newValue = date

                            return @setScalar query, newValue, result
                        else if verb in @verbSynonyms.delete or verb in @verbSynonyms.empty
                            return @unsetScalar result

                    # OBJECT
                    else if propertyType is 'Object'

                        if verb in @verbSynonyms.set
                            return @setObject query, newValue, result

                        else if verb in @verbSynonyms.add
                            return @respondWithError "I don't understand how to add #{if newValue then "#{newValue} to" else "to"} a #{property}"
                        else
                            return @respondWithError "I don't understand how to #{verb} a #{property}"

                    else
                        if verb in @verbSynonyms.set or verb in @verbSynonyms.add
                            return @setScalar query, newValue, result
                        # remove === empty
                        else if verb in @verbSynonyms.remove or verb in @verbSynonyms.empty
                            return @unsetScalar result
                        else
                            return @respondWithError "I don't understand how to #{verb} a scalar value"

                when 'suggestion'
                    result.suggestions = result.suggestions.map (r) -> "set #{r}"

                    if result.suggestions.length is 1
                        @jiri.recordOutcome @, @OUTCOME_SUGGESTION, {suggestion: result.suggestions[0], newValue: newValue}
                        text = "Did you mean `#{result.formattedSuggestions[0]}`?"
                    else
                        @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, {suggestions: result.suggestions, newValue: newValue}
                        result.formattedSuggestions = result.formattedSuggestions.map (r, i) -> "`#{i+1}` #{r}"
                        text = "Did you mean one of these?\n>>>\n#{result.formattedSuggestions.join "\n"}"

                when 'unknown'
                    # try again, now assuming it was a value
                    if @assumedSplitAddQuery
                        return @parseQuery verb, @assumedSplitAddQuery.query, arrayIndex, @assumedSplitAddQuery.newValue
                    bits = humanize.explainMatches result.matches
                    text = "I understood that #{joinn bits}, but I'm not sure I get the `#{lastMatch.query}` bit.\n\nCould you try rephrasing it?"
                    @jiri.recordOutcome @, @OUTCOME_INVALID

            text = "Sorry, I'm not able to decipher `#{verb} #{query}`. Try rephrasing?" unless text
        catch e
            console.log e.stack
            console.log result
            text = "I should be able to do that, but I'm not feeling at all well today. (That's an error, by the way)"

        return @respond text

    # changes the result object to replace the existing target & last match to use the given property
    switchTarget: (result, newProperty) ->
        parent = result.matches[result.matches.length-2].target
        result.matches[result.matches.length-1].property = newProperty
        result.target = parent[newProperty]
        result

    formatValueForDisplay: (value) ->
        unless value
            return '_empty_'

        if typeof value is 'object'
            type = @getObjectType value
            value = moment(value) if type is 'Date'

            if moment.isMoment value
                # if the time is midnight, assume we only care about the date
                if value.format('HH:mm:ss') is "00:00:00"
                    value = value.format('ll')
                else
                    value = value.format('llll')

            else if value.getName
                value = value.getName()
            else
                value = value.toString()

        return "`#{@jiri.slack.escape(value)}`"

    promptForValue: (query, arrayIndex, verb, targetPath, existingValue) =>
        @jiri.recordOutcome @, @OUTCOME_NO_VALUE_SPECIFIED, {query: query, arrayIndex: arrayIndex, verb: verb}
        if arrayIndex?
            text = "What do you want to change the #{converter.toWordsOrdinal arrayIndex+1} of _#{targetPath}_ to?"
        else
            text = "What do you want to change _#{targetPath}_ to?"
        text += "\n(it's currently #{@formatValueForDisplay existingValue}. Type `cancel` to cancel.)"
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
                return @promptForValue query, arrayIndex, 'set', targetPath, parent[property][arrayIndex]
            else
                return @setArrayValue parent, property, arrayIndex, newValue, targetPath, result.matches[0].target

        # user asked to 'set' whole array, which is an invalid operation. Need to be more specific
        else
            options = []
            count = if result.target?.length? then result.target.length else 0
            if newValue
                for child, i in result.target?
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
                            command: "set #{query.replace new RegExp("\\b#{property}\\b"), ''} #{childName} = #{newValue}"
                options.push
                    label: "`#{count+1}` Add a new #{inflect.singularize property}"
                    command: "add \"#{newValue}\" to #{query}"

            else
                if result.target
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
                                command: "set #{query.replace new RegExp("\\b#{property}\\b"), ''} #{childName}"
                options.push
                    label: "`#{count+1}` Add a new #{inflect.singularize property}"
                    command: "add #{query}"

            if result.target.length
                options.push
                    label: "`#{count+2}` Remove a #{inflect.singularize property}"
                    command: "remove #{query}"

            text = "What do you want to do with _#{humanize.getRelationalPath result.matches, false, true}_?\n>>>\n#{(o.label for o in options).join "\n"}"

            @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, suggestions: (o.command for o in options)

            return @respond text

    addToArray: (query, newValue, result) ->
        targetPath = humanize.getRelationalPath result.matches, false, true
        parent = result.matches[result.matches.length-2].target
        property = result.matches[result.matches.length-1].property
        # we'll assume that the property is plural
        singularProperty = inflect.singularize property
        array = result.target
        customer = result.matches[0].target

        # if it's an array of SubDocuments, we'll need to create a new instance
        if parent.schema.paths[property]?.schema
            try
                member = parent.schema.paths[property]
                nameProperty = member.schema.methods.getNameProperty()
                return @respondWithError "I don't know how to specify the name of a #{singularProperty}" unless nameProperty

                if newValue?

                    object = {}
                    object[nameProperty] = newValue

                    return @addArrayValue parent, property, object, targetPath, customer

                else
                    @jiri.recordOutcome @, @OUTCOME_NO_VALUE_SPECIFIED, {query: query, verb: 'add'}

                    # knock off the last match for the target path, so we can say “projects in Oxford” rather than “Oxford's projects”
                    result.matches.pop()
                    targetPath = humanize.getRelationalPath result.matches, false, true

                    if array.length is 0
                        text = "There currently aren't any #{property} in #{targetPath}"
                    else
                        if array.length is 1
                            text = "There is currently one #{singularProperty} in #{targetPath}"
                        else
                            text = "There are currently #{converter.toWords array.length} #{property} in #{targetPath}"

                        if array.length <= 3
                            text += ": \n```#{joinn (o[nameProperty] for o in array)}```"

                    text += "\n*What's the #{uncamelize nameProperty} of the new #{singularProperty}?* (type `cancel` to cancel)"

                    return @respond text
            catch e
                console.log e.stack

        # a scalar value
        else
            if newValue?
                return @addArrayValue parent, property, newValue, targetPath, customer
            else
                @jiri.recordOutcome @, @OUTCOME_NO_VALUE_SPECIFIED, {query: query, verb: 'add'}
                if array.length is 0
                    text = "_#{targetPath}_ is currently an empty list\n"
                else if array.length <= 3
                    text = "_#{targetPath}_ are currently: \n```#{joinn array}```\n"
                else
                    text = "_#{targetPath}_ are currently: \n```#{joinn array.slice(0,3)}```\n(and #{array.length - 3} more)\n"

                text += "*What do you want to add?* (type `nothing` to cancel)"

                return @respond text

    removeFromArray: (query, arrayIndex, result) ->
        if arrayIndex?
            parent = result.matches[result.matches.length-2].target
            property = result.matches[result.matches.length-1].property
            previousValue = result.target[arrayIndex]
            customer = result.matches[0].target

            parent[property].splice arrayIndex, 1
            saveMessage = "I've removed #{@formatValueForDisplay previousValue} from _#{humanize.getRelationalPath result.matches, false, true}_"

            if parent[property].length is 0
                saveMessage += ". All gone."
            else if parent[property].length is 1
                saveMessage += ". There's just one left now."
            else
                saveMessage += ". There are #{converter.toWords parent[property].length} now."

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
        options = []
        index = 1

        for own p, o of result.target.schema?.paths when p not in humanize.privateKeys
            value = result.target[p]
            if o.instance is 'Array'
                if value.length is 0
                    options.push
                        label: "`#{index++}` Add #{inflect.singularize humanize._humanizeKey(p, false).toLowerCase()}"
                        command: "add #{query} #{p}"
                else
                    options.push
                        label: "`#{index++}` Change #{humanize._humanizeKey(p, false).toLowerCase()}"
                        command: "set #{query} #{p}"
            else
                label = "`#{index++}` #{if value then "Change" else "Set"} #{humanize._humanizeKey(p, false).toLowerCase()}"
                label += " to #{@formatValueForDisplay newValue}" if newValue?
                options.push
                    label: label
                    command: "set #{query} #{p}"

        text = "What do you want to do with _#{humanize.getRelationalPath result.matches}_?\n>>>\n#{(o.label for o in options).join "\n"}"
        @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, suggestions: (o.command for o in options)

        return @respond text

    setScalar: (query, newValue, result) ->
        targetPath = humanize.getRelationalPath result.matches, true
        parent = result.matches[result.matches.length-2].target
        property = result.matches[result.matches.length-1].property

        unless newValue?
            return @promptForValue query, null, 'set', targetPath, parent[property]

        customer = result.matches[0].target

        return @setValue parent, property, newValue, targetPath, customer

    unsetScalar: (result) ->
        targetPath = humanize.getRelationalPath result.matches, true

        parent = result.matches[result.matches.length-2].target
        property = result.matches[result.matches.length-1].property
        customer = result.matches[0].target

        return @setValue parent, property, null, targetPath, customer


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

        hyperlinkRegex = new RegExp '^<(https?://[^ ]+)>$', 'i'
        if value.match hyperlinkRegex
            value = value.replace hyperlinkRegex, '$1'

        previousValue = parent[property]

        if value is previousValue
            @jiri.recordOutcome @
            return @respond "_#{targetPath}_ is already set to #{@formatValueForDisplay value}"

        @jiri.recordOutcome @, @OUTCOME_CHANGED

        if value is null
            parent[property] = undefined
        else
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

        # add a plain object
        parent[property].push value

        # get back the subdocument
        value = parent[property][parent[property].length-1]

        saveMessage = "I've added #{@formatValueForDisplay value} to #{targetPath}"

        if parent[property].length is 1
            saveMessage += ". It's the only one at present."
        else
            saveMessage += ". There are #{converter.toWords parent[property].length} now."

        if typeof value is 'object' and not moment.isDate(value)
            saveMessage += @getAvailablePropertiesString value

        @setLoading()
        return customer.save().then => @respond saveMessage


    addCustomer: (name, ignoreExisting = false) ->
        new Promise (resolve, reject) =>
            unless name?
                @jiri.recordOutcome @, @OUTCOME_NO_VALUE_SPECIFIED, query: 'customer', verb: 'add'
                return @respond "What's the name of the customer to add? (type `cancel` to cancel)"

            Customer = @customer_database.model 'Customer'

            if ignoreExisting
                promise = new Promise (resolve) -> resolve()
            else
                @setLoading()
                promise = Customer.findOneByName name
                .then (customer) =>
                    if customer
                        new Promise (resolve, reject) =>
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
                        strings = [
                            "Ladies and gentlemen, allow me to introduce our latest customer… *#{customer.name}* :tada:"
                            "Sorted. *#{customer.name}* it is."
                            "Introducing our latest customer… *#{customer.name}* :dancers:"
                            "A warm welcome to *#{customer.name}*, our latest customer :cheer:"
                            "Our latest customer: :star2: *#{customer.name}* :star2:"
                        ]
                        text = strings[Math.floor(Math.random() * strings.length)]
                        text += @getAvailablePropertiesString customer
                        return @respond text
                    , (error) =>
                        return @respondWithError error

    getAvailablePropertiesString: (object) ->
        o = if object.schema?.paths? then object.schema.paths else object
        "\n(properties you can set: #{(k for own k of o when k[0] != '_').map((s)->"`#{s}`").join(', ')})"

    getTestRegex: =>
        unless @pattern
            valueRegex = '[\'"“‘`<]?(.+?)[>\'"”’`]?'
            @pattern = @jiri.createPattern "^jiri set (?:#{valueRegex} (?:to|from) )?(.+?)(?:\\[(\\d+)\\])?(?: _to #{valueRegex})?$", @patternParts
        return @pattern.getRegex()

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        @jiri.getLastOutcome @
        .then (lastOutcome) =>
            @lastOutcome = lastOutcome
            mainRegexMatch = message.text.match @getTestRegex()
            cancelCommand = message.text.match(@jiri.createPattern('^jiri (cancel|undo|stop|ignore|nothing|none|neither)').getRegex())
            if @lastOutcome?.outcome is @OUTCOME_NO_VALUE_SPECIFIED and not mainRegexMatch
                @mode = if cancelCommand then @MODE_CANCEL else @MODE_SET_VALUE
                return true
            if (@lastOutcome?.outcome is @OUTCOME_SUGGESTIONS and message.text.match @getRegex('numberChoice')) or
               (@lastOutcome?.outcome is @OUTCOME_SUGGESTION and message.text.match @getRegex('yes'))
                @mode = @MODE_USE_SUGGESTION
                return true
            if @lastOutcome?.outcome in [@OUTCOME_SUGGESTIONS, @OUTCOME_SUGGESTION] and (cancelCommand or message.text.match(@getRegex('no')))
                @mode = @MODE_CANCEL
                return true

            @mode = @MODE_NEW
            return mainRegexMatch

module.exports = CustomerSetInfoAction
