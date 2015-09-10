stringUtils = require './string'
inflect = require('i')()
converter = require 'number-to-words'

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

    allCaps:
        url: 'URL'
        pm: 'PM'

    # Returns a human readable string representation of the object parameter
    dump: (object) ->
        @_cleanJson JSON.stringify(@_humanizeObject(object), null, 4)

    # Returns a human-readable path of the match targets
    #
    # @param    array   matches An array of {target: x, property: y}
    # @params   boolean showCountForLast    If true and the last target is an array, the length of that array will be included
    getRelationalPath: (matches, showCountForLast = true) ->
        targets = []

        for match, i in matches
            isLastMatch = i is matches.length-1
            if match.target?.getName
                targets.push match.target.getName(isLastMatch)
            else if @allCaps[match.property.toLowerCase()]
                targets.push @allCaps[match.property.toLowerCase()]
            else
                property = match.property
                if showCountForLast and isLastMatch and typeof match.target is 'object' and match.target.length
                    targets.push converter.toWords match.target.length
                    property = inflect.singularize match.property if match.target.length is 1
                targets.push stringUtils.uncamelize(property).toLowerCase()

        targets[0] += '’s' if targets.length > 1

        return targets.join ' '

    explainMatches: (matches) ->
        bits = []
        for match in matches
            name = if match.target.getName then match.target.getName() else match.property
            if match.keyword
                bits.push "`#{match.keyword.trim()}` is _#{name}_"
            else
                bits.push "(I assumed you meant the #{name})"
        return bits

    #########################

    _humanizeKey: (key) ->
        # some hardcoded abbreviations, so they are all caps
        return @allCaps[key.toLowerCase()] if @allCaps[key.toLowerCase()]

        s = stringUtils.upperCaseFirst stringUtils.uncamelize(key).trim()

    _humanizeObject: (object) ->
        switch typeof object
            # represent boolean as yes/no
            when 'boolean'
                return if object then 'yes' else 'no'

            when 'object'

                # array
                if object.length?
                    output = {}
                    count = 0
                    for property, v of @_unpackArraysForOutput '', object
                        key = @_humanizeKey property
                        value = @_humanizeObject v
                        output[key] = value
                        count++

                    if count is 1 and not key
                        output = value

                    return output

                # other object
                else
                    output = {}
                    arrayProperties = {}
                    objectProperties = {}

                    for own key, value of object
                        continue if key[0] is '_'

                        # we'll defer arrays and objects til later for nicer ordering
                        if typeof value is 'object' and value.length?
                            arrayProperties[key] = value
                        else if typeof value is 'object'
                            objectProperties[key] = value if value
                        else if key
                            output[@_humanizeKey key] = @_humanizeObject value

                    for own key, value of objectProperties
                        output[@_humanizeKey key] = @_humanizeObject value

                    for own key, value of arrayProperties
                        newProperties = @_unpackArraysForOutput key, value
                        for property, v of newProperties
                            output[@_humanizeKey property] = @_humanizeObject v

                    return output

            # return other scalar types unaltered
            else
                return object

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
                    output["*#{key}*"] = member
            else
                output["#{pluralKey}"] = array.join ", "

        return output

    # If the object has a property called 'name' or 'role',
    # return a key that incorporates that name, and remove it from the object itself
    #
    # If it doesn't have a name-like key, use the index to number the key,
    # or failing that just return the bare key.
    _getNamedKey: (object, singularKey, index = null) ->

        for key in ['name','role']
            if object[key]?
                name = object[key]
                delete object[key]
                break

        if name
            return "#{stringUtils.upperCaseFirst name} #{singularKey}"
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
