inflect = require './utils/inflect'
RSVP = require 'rsvp'
mongoose = require '../database_init'
Customer = mongoose.model 'Customer'
SubTargetMatch = require './SubTargetMatch'

class NaturalLanguageObjectReference

    # Constants
    RESULT_FOUND: 0
    RESULT_SUGGESTION: 1
    RESULT_UNKNOWN: 2
    RESULT_PRESUMED: 3

    constructor: (@query) ->

    # Attempts to identify the object referred to by the query string
    #
    # @return object
    #          int outcome         a RESULT_* constant
    #          object target       the object that the query definitely refers to
    #          array suggestions   an array of string queries that might be what the user intended.
    #                              Only returned with a MULTIPLE outcome
    #          array matches       an hash where keywords are string bits of the query that were understood and
    #                              the values are string names of the target they match.
    #                              Only returned with an UNKNOWN outcome
    findTarget: ->
        return new RSVP.Promise (resolve, reject) =>
            # The base objects are Customers, so look that up in the database first
            @extractCustomerName(@query)
            .then (match) =>
                matches = [match]

                try
                    while match.query
                        match = match.target.findSubtarget match.query

                        # exit loop once we get no more matches
                        break unless match

                        # avoid getting stuck
                        break if match.target is matches[matches.length-1].target

                        matches.push match

                        # keep going soon long as we're still dealing with Documents
                        break unless match.target?.findSubtarget

                    # If there's a match with no remainder, return it
                    if match and not match.query
                        return resolve
                            matches: matches
                            outcome: @RESULT_FOUND
                            target: match.target

                    # get the reference to the last match found
                    match = matches[matches.length - 1]

                    potentiallyIntendedTargets = []
                    if match.target and typeof match.target is 'object'
                        for property of match.target.toObject({virtuals: false, versionKey: false})
                            continue if property[0] is '_'

                            child = match.target[property]

                            if child and typeof child is 'object'
                                # is an array
                                if child.length
                                    for c in child when c.findSubtarget and target = c.findSubtarget(match.query)
                                        potentiallyIntendedTargets.push new SubTargetMatch
                                            property: property
                                            label: c.getName()
                                            target: target
                                # a single object
                                else
                                    if child.findSubtarget and target = child.findSubtarget(match.query)
                                        potentiallyIntendedTargets.push new SubTargetMatch
                                            property: property
                                            label: property
                                            target: target

                    if potentiallyIntendedTargets.length
                        keywords = (m.keyword.trim() for m in matches when m).join ' '
                        suggestions = []
                        formattedSuggestions = []
                        for potentiallyIntendedTarget in potentiallyIntendedTargets
                            suggestions.push "#{keywords.trim()} #{potentiallyIntendedTarget.label} #{match.query}"
                            formattedSuggestions.push "#{keywords.trim()} _#{potentiallyIntendedTarget.label}_ #{match.query}"

                        return resolve
                            matches: matches
                            outcome: @RESULT_SUGGESTION
                            suggestions: suggestions
                            formattedSuggestions: formattedSuggestions

                    else
                        return resolve
                            outcome: @RESULT_UNKNOWN
                            matches: matches

                catch e
                    console.log e.stack
                    reject e

            .catch reject

    ####
    # Finds a customer name in the query, and returns the Customer object (via a Promise)
    # 
    # @param string query
    # @return Promise
    extractCustomerName: (query) ->
        return new RSVP.Promise (resolve, reject) =>
            Customer.getAllNameRegexString()
            .then (customerRegexString) =>
                regexs = [
                    new RegExp("^#{customerRegexString}\\b\\s*", 'i'),
                    new RegExp("\\bfor\\s+(#{customerRegexString})\\b\\s*", 'i')
                ]
                try
                    for regex in regexs
                        m = query.match regex
                        if m
                            query = query.replace regex, ''
                            return Customer.findOneByName m[1]
                                .then (customer) ->
                                    return reject "Sorry, I couldn't figure out which customer `#{m[1]}` is" unless customer
                                    return resolve new SubTargetMatch
                                        query: query
                                        keyword: m[1].trim()
                                        target: customer
                                .catch (error) ->
                                    console.log error.stack
                                    return reject "Sorry, I couldn't load data about #{m[1]}"

                    return reject "Sorry, I can't see a customer in `#{query}`"
                catch e
                    return reject e


            .catch ->
                return reject "Unable to load customers data"

module.exports = NaturalLanguageObjectReference
