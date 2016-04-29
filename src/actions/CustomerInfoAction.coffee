RSVP = require 'rsvp'
joinn = require 'joinn'
Action = require './Action'
Pattern = require '../Pattern'
humanize = require '../utils/humanize'

# Query Customer database in natural language
#
class CustomerInfoAction extends Action

    # result was found — no follow up expected
    OUTCOME_FOUND: 0
    # single suggestion — user can say 'yes'
    OUTCOME_SUGGESTION: 1
    # multiple suggestions — user can select by number
    OUTCOME_SUGGESTIONS: 2
    # unknown property
    OUTCOME_UNKNOWN: 3
    # found property with empty value
    OUTCOME_EMPTY: 3

    patternParts:
        find: "(is|find|show|display|get|tell (me|us) about|when (did|does)|(what|who|where|when)([’']?s| is| are)?)( +the)?"
        yes: "^jiri y(es|ep|up)?\\s*(please|thanks|thank you|cheers|mate)?$"
        numberChoice: "^jiri (\\d+)\\s*(please|thanks|thank you|cheers)?$"
        whatVersion: "what (?:(.*?) )version(?: is|'s')"

    # should return the class name as a string
    getType: ->
        return 'CustomerInfoAction'

    describe: ->
        return 'provide information about customers\' projects'

    respondTo: (message) ->
        query = ''
        return new RSVP.Promise (resolve, reject) =>
            if @lastOutcome?.outcome is @OUTCOME_SUGGESTION and message.text.match @jiri.createPattern(@patternParts.yes).getRegex()
                query = @lastOutcome.data

            else if @lastOutcome?.outcome is @OUTCOME_SUGGESTIONS and m = message.text.match @jiri.createPattern(@patternParts.numberChoice).getRegex()
                index = parseInt(m[1], 10)-1
                if @lastOutcome.data[index]
                    query = @lastOutcome.data[index]
                else
                    return resolve
                        text: "That wasn't one of the options!"
                        channel: @channel.id

                return resolve query
            else
                return resolve @getTestRegexes().then (testRegexes) =>
                    # convert a 'what version' query to standard form
                    if m = message.text.match testRegexes.whatVersion
                        customer = m[3].replace /[!.?\s]+$/, ''
                        query = "#{customer} #{m[2]} version"

                    else
                        query = message.text.replace(@jiri.createPattern('^jiri find\\s+', @patternParts).getRegex(), '')
                                # remove trailing question mark
                                .replace /[!.?\s]+$/, ''

                        # a flag to show properties that would otherwise be hidden
                        showHiddenRegex = /[ ](full|includ(ing|e) hidden)$/i
                        if query.match showHiddenRegex
                            query = query.replace showHiddenRegex, ''
                            @showHiddenProperties = true

                    query

        .then (query) =>
            # remove any 'apostrophe s'
            query = query.replace /(\w)['’]+s /g, '$1 '

            @setLoading()
            Customer = @customer_database.model 'Customer'
            Customer.resolveNaturalLanguage query

        .catch (e) =>
            console.log e.stack||e
            return text: e, channel: @channel.id

        .then (result) =>
            switch result.outcome
                when 'found'
                    targetPath = humanize.getRelationalPath result.matches

                    if typeof result.target is 'undefined'
                        text = "I'm afraid I don't have any information about _#{targetPath}_\n(if you find out, let me know)"
                        @jiri.recordOutcome @, @OUTCOME_EMPTY

                    else
                        if result.target in [true,false]
                            text = "_Is #{targetPath}_? *#{humanize.dump(result.target)}*"
                        else if typeof result.target is 'number' or Object.prototype.toString.call(result.target) is '[object Date]' or (typeof result.target is 'string' and result.target.length < 16 or (result.target.length < 32 and result.target.indexOf(' ') > -1))
                            text = "*#{targetPath}*: `#{humanize.dump(result.target).replace(/\\n/g, "; ")}`"
                        else
                            output = humanize.dump(result.target, @showHiddenProperties).replace(/\\n/g, "; ")
                            if output is '(an empty object)'
                                text = "*#{targetPath}*:\n```#{output}```\nType `#{query} full` to show empty properties too"
                            else if output
                                text = "*#{targetPath}*:\n```#{output}```"
                            else
                                text = "*#{targetPath}*: _(empty)_"
                        @jiri.recordOutcome @, @OUTCOME_FOUND

                when 'suggestion'
                    if result.suggestions.length is 1
                        @jiri.recordOutcome @, @OUTCOME_SUGGESTION, result.suggestions[0]
                        text = "Did you mean “#{result.formattedSuggestions[0]}”?"
                    else
                        @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, result.suggestions
                        result.formattedSuggestions = result.formattedSuggestions.map (r, i) -> "`#{i+1}` #{r}"
                        text = "Did you mean one of these?\n>>>\n#{result.formattedSuggestions.join "\n"}"

                when 'unknown'
                    match = result.matches[result.matches.length-1]
                    bits = humanize.explainMatches result.matches
                    text = "I understood that #{joinn bits}, but I'm not sure I get the `#{match.query}` bit.\n\nCould you try rephrasing it?"
                    @jiri.recordOutcome @, @OUTCOME_UNKNOWN

                else
                    return text: result.text, channel: @channel.id

            text = "Sorry, I'm not able to decipher `#{query}`. Try rephrasing?" unless text

            return text: text, channel: @channel.id, unfurl_links: false

    getTestRegexes: =>
        Customer = @customer_database.model 'Customer'
        Customer.schema.statics.getAllNameRegexString().then (customerRegex) =>
            unless @patterns
                @patterns =
                    find: @jiri.createPattern("^jiri find +.*(?=#{customerRegex}).*", @patternParts),
                    whatVersion: @jiri.createPattern('^jiri whatVersion\\s+(\\S.+?)(?: on| running| at)?\\?*$', @patternParts, true),
            output = {}
            output[name] = pattern.getRegex() for own name, pattern of @patterns
            return output

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        @jiri.getLastOutcome @
        .then (lastOutcome) =>
            @lastOutcome = lastOutcome
            return true if @lastOutcome?.outcome is @OUTCOME_SUGGESTION and message.text.match @jiri.createPattern(@patternParts.yes).getRegex()
            return true if @lastOutcome?.outcome is @OUTCOME_SUGGESTIONS and message.text.match @jiri.createPattern(@patternParts.numberChoice).getRegex()
            @getTestRegexes().then (regexes) =>
                for own name,regex of regexes
                    return true if message.text.match regex
                return false

module.exports = CustomerInfoAction
