RSVP = require 'rsvp'
Action = require './Action'
Pattern = require '../Pattern'
mongoose = require '../../database_init'
Customer = mongoose.model 'Customer'
stringUtils = require '../utils/string'
humanize = require '../utils/humanize'
regexEscape = require 'escape-string-regexp'
converter = require 'number-to-words'
inflect = require('i')()

# Query Customer database in natural language
#
class CustomerListAction extends Action

    OUTCOME_FOUND: 0
    OUTCOME_NONE: 1
    OUTCOME_ERROR: 2
    OUTCOME_COUNTED: 3

    MODE_LIST: 0
    MODE_COUNT: 1

    patternParts:
        count: 'count|how many|what number of'
        list: 'list|show|display|output|which'
        like: 'like|contain(ing)?|with|match(ing)?|(is|are )?(called|named)'
        customers: 'customers|clients|customer'

        yes: "jiri y(es|ep|up)?\\s*(please|thanks|thank you|cheers|mate)?"
        no: "jiri (n|no|nope|nah)( (thanks|thank you|cheers))?"

    # should return the class name as a string
    getType: ->
        return 'CustomerListAction'

    describe: ->
        return 'list/search for customers'

    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            @setLoading()

            # the user has answered 'no', so no need to reply
            if @lastOutcome?.outcome is @OUTCOME_COUNTED and message.text.match @getRegex('no', false)
                return resolve()

            m = message.text.match @getTestRegex()

            if m[1].match @getRegex('count')
                mode = @MODE_COUNT
            else
                mode = @MODE_LIST

            if m[2].match @getRegex('customers')
                set = 'customers'
            else
                return reject "I'm not sure what #{m[1]} is"

            filter = m[3]
            # remove quote marks from filter, if any
            filter = filter.replace(/(^["'“‘]|["'“‘?]$)/g, '') if filter

            queryObject = null
            if set is 'customers'
                if filter
                    if filter.match /[\^$|()*?+.{}[\]]/
                        filterRegex = new RegExp(filter, 'i')
                        search = Customer.find $or: [{name: filterRegex}, {aliases: filterRegex}]
                        filterName = "with a name matching the regular expression `/#{filter}/i`"
                    else
                        filterName = "with a name containing “#{filter}”"
                        search = Customer.findByName(filter)

                # unfiltered
                else
                    search = Customer.find()

            search.then (results) =>
                if results.length

                    if mode is @MODE_LIST or (mode is @MODE_COUNT and results.length < 5)
                        @jiri.recordOutcome @, @OUTCOME_FOUND
                        if results.length is 1
                            title = "Here is the one #{inflect.singularize set}"
                        else
                            title = "Here are the #{converter.toWords results.length} #{set}"
                        title += " #{filterName}" if filterName
                        text = "*#{title}*:\n>>>\n"
                        text += (result.getName() for result in results).join "\n"

                    else
                        @jiri.recordOutcome @, @OUTCOME_COUNTED, m[0].replace(@getRegex('count', false), 'list')
                        if results.length is 1
                            title = "There is just one #{inflect.singularize set}"
                        else
                            title = "There are #{converter.toWords results.length} #{set}"
                        title += " #{filterName}" if filterName
                        text = "*#{title}*\nDo you want to see them?"

                else
                    @jiri.recordOutcome @, @OUTCOME_NONE
                    text = "Alas, I couldn't find _any_ #{set}"
                    text += " #{filterName}" if filterName

                return resolve
                    text: text
                    channel: @channel.id
                    unfurl_links: false

            .catch (error) =>
                @jiri.recordOutcome @, @OUTCOME_ERROR
                return resolve
                    text: error
                    channel: @channel.id

    getTestRegex: =>
        unless @pattern
            @pattern = @jiri.createPattern('^jiri (count|list) (?:all |the |our )*(customers|projects)(?: +like (.+))?$', @patternParts)
        return @pattern.getRegex()

    getRegex: (part, whole = true) ->
        return null unless @patternParts[part]
        partRegex = @patternParts[part]
        if whole
            return @jiri.createPattern("^#{partRegex}$").getRegex()
        else
            return @jiri.createPattern("\\b(#{partRegex})\\b").getRegex()

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) =>
        @lastOutcome = @jiri.getLastOutcome @
        if @lastOutcome?.outcome is @OUTCOME_COUNTED and message.text.match @getRegex('yes')
            message.text = @lastOutcome.data
            return true
        return true if @lastOutcome?.outcome is @OUTCOME_COUNTED and message.text.match @getRegex('no')
        return message.text.match @getTestRegex()

module.exports = CustomerListAction
