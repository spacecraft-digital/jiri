stringUtils = require './string'
inflect = require './inflect'
converter = require 'number-to-words'
moment = require 'moment'

# Humanize
#
# Given a variable of any type, returns a nice, human-readable string repesentation
#
# Starts with a JSON representation of the object,
#   • uncamelises keys (fooBarBaz becomes Foo Bar Baz)
#   • removes messy syntax characters like commas, brackets and quotes
#   • breaks each array member out as a direct property of their parents,
#     incorporating a name-like property of the member (if available) as the key
#   • and some other cleaning up
#
#  Usage:
#     humanize = require './humanize'
#     output = humanize.dump object
#     console.log output

module.exports =

    # words that should have certain capitalisation
    allCaps: 'URL URLs SSH PM CMS XFP LAMP ID HTTP HTTPS Jadu QA UAT'

    # general string replacements to perform
    #
    # Useful for words that are naturally camelCased
    replacements:
        "Git Lab": "GitLab"
        "Git Hub": "GitHub"

    # Returns a human readable string representation of the object parameter
    dump: (object, showHiddenProperties = false) ->
        @_cleanJson(JSON.stringify(@_humanizeObject(object, showHiddenProperties), null, 4)).trim()

    # Returns a human-readable path of the match targets
    #
    # @param    array   matches An array of {target: x, property: y}
    # @params   boolean showCountForLast    If true and the last target is an array, the length of that array will be included
    getRelationalPath: (matches, showCountForLast = true, forcePluralLast = false) ->
        targets = []

        for match, i in matches
            isLastMatch = i is matches.length-1
            if match.target?.getName
                targets.push match.target.getName(isLastMatch)
            # private properties stay as-is
            else if match.property[0] is '_'
                targets.push match.property
            else
                property = match.property
                if isLastMatch and forcePluralLast
                    property = inflect.pluralize property

                if showCountForLast and isLastMatch and typeof match.target is 'object' and match.target.length
                    if match.target.length is 1
                        property = inflect.singularize property
                    else if not forcePluralLast
                        targets.push converter.toWords match.target.length
                        property = inflect.pluralize property

                property = stringUtils.uncamelize(property).toLowerCase()

                targets.push @_fixCapitalisation(property)

        targets[0] += '’s' if targets.length > 1

        return targets.join ' '

    explainMatches: (matches) ->
        bits = []
        for match in matches
            name = if match.target?.getName then match.target.getName() else match.property
            if match.keyword
                bits.push "`#{match.keyword.trim()}` is _#{name}_"
            else
                bits.push "(I assumed you meant the #{name})"
        return bits

    #########################

    # Fix the capitalisation of some known abbreviations (e.g. URL, SSH)
    _fixCapitalisation: (s) ->
        # convert to array
        @allCaps = @allCaps.split(' ') if typeof @allCaps is 'string'

        # replace some known abbreviation with correct case
        for abbrev in @allCaps
            s = s.replace new RegExp("\\b#{abbrev}\\b","ig"), abbrev

        for own find, replace of @replacements
            s = s.replace new RegExp("\\b#{find}\\b","ig"), replace

        return s

    _humanizeKey: (key) ->
        s = stringUtils.upperCaseFirst stringUtils.uncamelize(key).trim()
        @_fixCapitalisation s

    _humanizeObject: (object, showHiddenProperties = false, depth = 0) ->
        switch typeof object
            # represent boolean as yes/no
            when 'boolean'
                return if object then 'yes' else 'no'

            when 'object'

                if object is null
                    return 'NULL'

                else if object instanceof Date
                    return moment(object).calendar null,
                        sameElse: 'dddd LL'

                # array
                else if object.length?
                    output = {}
                    count = 0
                    for property, v of @_unpackArraysForOutput '', object
                        @_addValueToOutput property, v, depth, output, showHiddenProperties
                        count++

                    # if the result is an array of one object, collapse it into the parent
                    if count is 1 and not property
                        output = output[Object.keys(output)[0]]

                    return '(an empty array)' if count is 0

                    return output

                # other object
                else
                    originalObject = object

                    # Allow objects to return a different set of properties at different depths
                    # This allows objects to return a more concise representation of themselves
                    # when they are being including in a dump as children/grandchildren of the main object
                    if object.toObjectAtDepth
                        object = object.toObjectAtDepth depth
                    # for Mongoose Document objects, the original can be accessed at originalObject to call methods on
                    # but the `object` var then contains a vanilla JS object
                    else if object.toObject
                        object = object.toObject()

                    output = {}

                    keys = Object.keys(object)

                    # if we're showing hidden properties, ensure all properties are presented
                    if showHiddenProperties
                        for key in keys when key != '_id'
                            if typeof object[key] is 'object' and object[key].length?
                                output[@_humanizeKey key] = '[]'
                            else if typeof object[key] != 'object'
                                output[@_humanizeKey key] = ' '

                    # get the property used in the getName() method, to avoid including it twice
                    nameProperty = if originalObject.getNameProperty then originalObject.getNameProperty() else null

                    for key in keys when key is '_id' or (not showHiddenProperties and (key[0] is '_' or key is nameProperty))
                        # remove keys we want to ignore
                        delete object[key]

                    keys = Object.keys(object)

                    # if the object has a single scalar value, we'll collapse it with the parent property
                    if keys.length is 1 and typeof object[keys[0]] != 'object' and depth > 0
                        return {
                            __object_as_string: true
                            key: keys[0]
                            value: object[keys[0]]
                        }

                    for own key, value of object
                        if value and typeof value is 'object' and value.length?
                            newProperties = @_unpackArraysForOutput key, originalObject[key]
                            for property, v of newProperties
                                @_addValueToOutput property, v, depth, output, showHiddenProperties
                        else if key and value and (typeof value != 'object' or value instanceof Date or Object.keys(value).length)
                            @_addValueToOutput key, value, depth, output, showHiddenProperties

                    return output

            # return other scalar types unaltered
            else
                return object

    # A method to add a property to the output object
    #
    # It facilitates a sub object with a single value being flattened
    # into the parent property, with the keys being merged
    #
    # e.g. {"CMS": {"version": "1.12.1.15"}}
    # can be flattened to {"CMS version": "1.12.1.15"}
    _addValueToOutput: (key, value, depth, output, showHiddenProperties = false) ->
        value = @_humanizeObject value, showHiddenProperties, depth+1

        # an object with a single value should be displayed as a string
        if value.__object_as_string
            key = "#{key} #{value.key}"
            value = value.value

        output[@_humanizeKey key] = value

    _unpackArraysForOutput: (key, array) ->
        output = {}

        # ignore empty arrays
        return output if array.length is 0

        pluralKey = @_humanizeKey key
        singularKey = inflect.singularize pluralKey

        if array.length is 1
            member = array[0]
            output[@_getNamedKey(member, singularKey)] = member
        else
            if typeof array[0] is 'object'
                index = 0
                for member in array
                    index++
                    key = @_getNamedKey(member, singularKey, index)
                    output["#{key}"] = member
            else
                output["#{pluralKey}"] = array.join ", "

        return output

    # If the object has a property called 'name' or 'role',
    # return a key that incorporates that name, and remove it from the object itself
    #
    # If it doesn't have a name-like key, use the index to number the key,
    # or failing that just return the bare key.
    _getNamedKey: (object, singularKey, index = null) ->
        if object.getName
            return object.getName true
        else if index
            return "#{singularKey} #{index}"
        else
            return "#{singularKey}"

    # Converts a JSON string for human-readable output.
    # Basically removes superfluous syntax characters (brackets, quote marks, commas, etc)
    # and tweaks the layout
    _cleanJson: (json) ->
        json = (''+json).replace(/,$/gm, '')
                # remove lines containing just a bracket
                .replace(/^ *[{}[\]] *(\n|$)/gm, '')
                # remove brackets at end of lines
                .replace(/: [{}[\]] *$/gm, ':')
                # remove quotes
                .replace(/"/g,'')

        # read the indentation of the first line
        if m = json.match /^ +/
            # and unindent the block so it starts from the origin
            json = json.replace new RegExp("^ {#{m[0].length}}", 'mg'), ''

        json
