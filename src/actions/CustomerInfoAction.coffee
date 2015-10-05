RSVP = require 'rsvp'
Action = require './Action'
Pattern = require '../Pattern'
mongoose = require '../../database_init'
Customer = mongoose.model 'Customer'
stringUtils = require '../utils/string'
humanize = require '../utils/humanize'
NaturalLanguageObjectReference = require '../NaturalLanguageObjectReference'

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
        find: "(find|show|display|get|tell (me|us) about|(what|who|where)([’']s| is| are)?)( +the)?"
        yes: "^jiri y(es|ep|up)?\\s*(please|thanks|thank you|cheers|mate)?$"
        numberChoice: "^jiri (\\d+)\\s*(please|thanks|thank you|cheers)?$"
        whatVersion: "what (?:(.*?) )version(?: is|'s')"

    # should return the class name as a string
    getType: ->
        return 'CustomerInfoAction'

    describe: ->
        return 'provide information about customers\' projects'

    respondTo: (message) ->
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

            else
                # convert a 'what version' query to standard form
                if m = message.text.match @getTestRegexes().whatVersion
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

            # remove any 'apostrophe s'
            query = query.replace /(\w)['’]+s /g, '$1 '

            @setLoading()
            ref = new NaturalLanguageObjectReference query
            ref.findTarget()
                .then (result) =>
                    try
                        switch result.outcome
                            when NaturalLanguageObjectReference.prototype.RESULT_FOUND
                                targetPath = humanize.getRelationalPath result.matches

                                if typeof result.target is 'undefined'
                                    text = "I'm afraid I don't have any information about _#{targetPath}_\n(if you find out, let me know)"
                                    @jiri.recordOutcome @, @OUTCOME_EMPTY

                                else
                                    if result.target in [true,false]
                                        text = "_Is #{targetPath}_? *#{humanize.dump(result.target)}*"
                                    else if typeof result.target is 'number' or (typeof result.target is 'string' and result.target.length < 60)
                                        text = "*#{targetPath}*: `#{humanize.dump(result.target).replace(/\\n/g, "; ")}`"
                                    else
                                        output = humanize.dump(result.target, @showHiddenProperties).replace(/\\n/g, "; ")
                                        if output is '(an empty object)'
                                            text = "*#{targetPath}*:\n```#{output}```\n(type `#{query} full` to show empty properties too)"
                                        else if output
                                            text = "*#{targetPath}*:\n```#{output}```"
                                        else
                                            text = "*#{targetPath}*: _(empty)_"
                                    @jiri.recordOutcome @, @OUTCOME_FOUND

                            when NaturalLanguageObjectReference.prototype.RESULT_SUGGESTION
                                if result.suggestions.length is 1
                                    @jiri.recordOutcome @, @OUTCOME_SUGGESTION, result.suggestions[0]
                                    text = "Did you mean “#{result.formattedSuggestions[0]}”?"
                                else
                                    @jiri.recordOutcome @, @OUTCOME_SUGGESTIONS, result.suggestions
                                    result.formattedSuggestions = result.formattedSuggestions.map (r, i) -> "`#{i+1}` #{r}"
                                    text = "Did you mean one of these?\n>>>\n#{result.formattedSuggestions.join "\n"}"

                            when NaturalLanguageObjectReference.prototype.RESULT_UNKNOWN
                                match = result.matches[result.matches.length-1]
                                bits = humanize.explainMatches result.matches
                                text = "I understood that #{stringUtils.join bits}, but I'm not sure I get the `#{match.query}` bit.\n\nCould you try rephrasing it?"
                                @jiri.recordOutcome @, @OUTCOME_UNKNOWN

                    catch e
                        console.log e.stack
                        return reject(e)

                    text = "Sorry, I'm not able to decipher `#{query}`. Try rephrasing?" unless text

                    return resolve
                        text: text
                        channel: @channel.id
                        unfurl_links: false

                .catch (error) =>
                    return resolve
                        text: error
                        channel: @channel.id

    getTestRegexes: =>
        unless @patterns
            @patterns =
                find: @jiri.createPattern("^jiri find +.*(?=#{Customer.schema.statics.allNameRegexString}).*", @patternParts),
                whatVersion: @jiri.createPattern('^jiri whatVersion\\s+(\\S.+?)(?: on| running| at)?\\?*$', @patternParts, true),
        output = {}
        output[name] = pattern.getRegex() for own name, pattern of @patterns
        return output

    # Returns TRUE if this action can respond to the message
    # No further actions will be tested if this returns TRUE
    test: (message) ->
        new RSVP.Promise (resolve) =>
            @lastOutcome = @jiri.getLastOutcome @
            return resolve true if @lastOutcome?.outcome is @OUTCOME_SUGGESTION and message.text.match @jiri.createPattern(@patternParts.yes).getRegex()
            return resolve true if @lastOutcome?.outcome is @OUTCOME_SUGGESTIONS and message.text.match @jiri.createPattern(@patternParts.numberChoice).getRegex()
            for own name,regex of @getTestRegexes()
                return resolve true if message.text.match regex
            return resolve false

module.exports = CustomerInfoAction
