
stringUtils = require '../src/utils/string'
SubTargetMatch = require '../src/SubTargetMatch'

####
# Static and instance methods to be used in all Schemas
#
_Base =
    # statics:

    methods:
        # returns a single result that can be considered the 'default' one of the set
        # In this standard implementation, this is just the first,
        # but in other schemas (e.g. Project), it may be marked in a different way
        #
        # @param string property    Property is the name of an Array property of this Document
        getDefault: (property) ->
            if @[property]?.length
                return @[property][0]

        # Returns an array of partial regular expressions to match the given property
        # of the current document
        #
        # This base implementation will match the property name and the uncamelised form
        # e.g. property @foo would be identified at the start of "foo bar"
        #      property @fooBar would be identified in "fooBar baz" and "foo bar baz"
        getPropertyRegexParts: (property) ->
            parts = []

            # require private properties (beginning with an underscore) to be named exactly
            if property[0] is '_'
                parts.push property
            else
                # allow dashes and spaces to be used interchangeably
                makeFlexibleWordDividers = (s) -> s.replace(/[-_ ]/g,'[ \\-_]*')

                uncamelizedPropertyRegex = stringUtils.uncamelize(property)
                parts.push makeFlexibleWordDividers(uncamelizedPropertyRegex)

            if typeof @[property] is 'object' and @[property]?.getNameRegexString
                parts.push @[property].getNameRegexString()

            parts

        # Returns a property that appears at the start of the query
        #
        # @return object with properties:
        #   target   the property that matched the query string
        #   keyword    the string found at the start of the query
        #   query    the updated query, with the match removed
        findSubtarget: (query) ->
            object = @.toObject getters: true, virtuals: true, versionKey: false, minimize: false

            for own property of object
                match = @propertyVariantsMatchQuery @, property, query
                return match if match

            # check members of array properties
            for own property, child of object when typeof child is 'object' and child? and child.length?
                for own childProperty of child
                    match = @propertyVariantsMatchQuery child, childProperty, query
                    return match if match

            return

        propertyVariantsMatchQuery: (parent, property, query) ->
            return unless parent.getPropertyRegexParts

            # get the name regex of each member of array
            if typeof parent[property] is 'object' and parent[property]?.length
                for child, i in parent[property] when child.getNameRegexString
                    m = query.match new RegExp "^(#{child.getNameRegexString()})\\b\\s*", 'i'
                    return if m
                        new SubTargetMatch
                            target: parent[property][i]
                            keyword: m[0]
                            query: query.replace m[0], ''
                            property: property

            regexParts = parent.getPropertyRegexParts property
            m = query.match new RegExp "^(#{regexParts.join('|')})\\b\\s*", 'i'
            return if m
                new SubTargetMatch
                    target: parent[property]
                    keyword: m[0]
                    query: query.replace m[0], ''
                    property: property

        toString: -> @getName()

        toJSON: ->
            @.toObject()

        # All Documents have a getName function, which gives a short text representation of the document
        getName: -> @name

        # returns the property that is used within getName
        # If it's not 'name', override this
        getNameProperty: -> 'name'


    #######################################

    ####
    # Adds all the static and instance methods from this base class
    # onto a given schema
    applyTo: (schema) ->
        schema.statics[method] = func for method, func of @statics
        schema.methods[method] = func for method, func of @methods

module.exports = _Base
