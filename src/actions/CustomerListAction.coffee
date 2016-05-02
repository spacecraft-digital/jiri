Action = require './Action'
Pattern = require '../Pattern'
humanize = require '../utils/humanize'
converter = require 'number-to-words'
inflect = require '../utils/inflect'

# Query Customer database in natural language
#
class CustomerListAction extends Action

    OUTCOME_FOUND: 0
    OUTCOME_NONE: 1
    OUTCOME_ERROR: 2
    OUTCOME_COUNTED: 3

    MODE_LIST: 0
    MODE_COUNT: 1

    # These constants control auto switching between 'list' and 'count' mode
    # If the user does a list, and there are lots of results, just show the count and let them confirm to show all.
    # If the user does a count, but there are only a handful of results, just show them anyway
    RATHER_A_LOT: 30
    ONLY_A_FEW: 5

    patternParts:
        count: 'count|how many|what number of'
        list: 'list|show|display|output|which'
        like: 'like|contain(ing)?|with|match(ing)?|(is|are )?(called|named)'
        where: 'where ([a-z_\.0-9]+) (=|is|contains)'
        customers: 'customers|clients|customer'

        yes: "jiri y(es|ep|up)?\\s*(please|thanks|thank you|cheers|mate)?"
        no: "jiri (n|no|nope|nah)( (thanks|thank you|cheers))?"

    # should return the class name as a string
    getType: ->
        return 'CustomerListAction'

    describe: ->
        return 'list/search for customers'

    respondTo: (message) ->
        return new Promise (resolve, reject) =>

            # the user has answered 'no', so no need to reply
            if @lastOutcome?.outcome is @OUTCOME_COUNTED and message.text.match @getRegex('no', false)
                return resolve()

            [..., forceMatch, modeMatch, setMatch, propertyMatch, filter] = message.text.match @getTestRegex()

            force = forceMatch and forceMatch.match /force /i

            if modeMatch.match @getRegex('count')
                mode = @MODE_COUNT
            else
                mode = @MODE_LIST

            if setMatch.match @getRegex('customers')
                set = 'customers'
            else
                return reject "I'm not sure what #{setMatch} is"

            filterRegex = null
            if filter
                # remove quote marks from filter, if any
                filter = filter.replace(/(^["'“‘]|["'“‘?]$)/g, '')
                if filter.match /[\^$|()*?+.{}[\]]/
                    filter = filter.replace(/(^\/|\/$)/g, '')
                    filterRegex = new RegExp(filter, 'i')

            searchProperty = 'name'
            if m = propertyMatch?.match @getRegex('where')
                searchProperty = m[1]

            Customer = @customer_database.model 'Customer'

            try
                if set is 'customers'
                    if filter
                        # special-case 'name' to also search aliases
                        if searchProperty is 'name'
                            if filterRegex
                                search = Customer.find $or: [{name: filterRegex}, {aliases: filterRegex}]
                                filterName = "with a name matching the regular expression `/#{filter}/i`"
                            else
                                filterName = "with a name containing “#{filter}”"
                                search = Customer.findByName(filter)
                        else
                            if filterRegex
                                search = Customer.find "#{searchProperty}": filterRegex
                                filterName = "where #{searchProperty} matches the regular expression `/#{filter}/i`"
                            else if filter is 'empty'
                                filterName = "where #{searchProperty} is empty"
                                search = Customer.find "#{searchProperty}": null
                            else if filter is 'not empty'
                                filterName = "where #{searchProperty} is not empty"
                                search = Customer.find "#{searchProperty}": {$exists: true}
                            else
                                filterName = "where #{searchProperty} contains “#{filter}”"
                                search = Customer.find "#{searchProperty}": filter
                    # unfiltered
                    else
                        search = Customer.find()
            catch e
                console.log e.stack

            search.then (results) =>
                try
                    if results?.length

                        # if there are lots of results, we'll check that the user wants to see them
                        if mode is @MODE_LIST and results.length >= @RATHER_A_LOT and not force
                            mode = @MODE_COUNT

                        if mode is @MODE_LIST or (mode is @MODE_COUNT and results.length <= @ONLY_A_FEW)
                            @jiri.recordOutcome @, @OUTCOME_FOUND
                            if results.length is 1
                                title = "Here is the one #{inflect.singularize set}"
                            else
                                title = "Here are the #{converter.toWords results.length} #{set}"
                            title += " #{filterName}" if filterName
                            text = "*#{title}*:\n>>>\n"
                            text += (result.getName() for result in results).join "\n"

                        else
                            # convert query to 'force list'
                            forcedQuery = message.text.replace(@jiri.createPattern('^jiri (force )?(count|list)\\b', @patternParts).getRegex(), 'jiri force list')
                            @jiri.recordOutcome @, @OUTCOME_COUNTED, forcedQuery
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
                        unfurl_links: false
                catch e
                    console.log e.stack

            .catch (error) =>
                @jiri.recordOutcome @, @OUTCOME_ERROR
                return resolve
                    text: error

    getTestRegex: =>
        unless @pattern
            @pattern = @jiri.createPattern('^jiri (force )?(count|list) (?:all |the |our )*(customers|projects)(?: +(like|where) (.+))?$', @patternParts)
        return @pattern.getRegex()

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        new Promise (resolve) =>
            resolve @jiri.getLastOutcome @
        .then (lastOutcome) =>
            @lastOutcome = lastOutcome
            if @lastOutcome?.outcome is @OUTCOME_COUNTED and message.text.match @getRegex('yes')
                message.text = @lastOutcome.data
                return true
            return true if @lastOutcome?.outcome is @OUTCOME_COUNTED and message.text.match @getRegex('no')
            return message.text.match @getTestRegex()

module.exports = CustomerListAction
