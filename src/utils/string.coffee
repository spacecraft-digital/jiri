regexEscape = require 'escape-string-regexp'

#
#  Various string utility functions
#
stringUtils =
    # Returns a more useful typeof, returning the class name for objects
    typeOf: (object) ->
        if typeof object is 'object'
            return Object.prototype.toString.call(object)
                    .toLowerCase()
                    .replace /^\[object (.+)]$/, '$1'
        else
            return typeof object

    # Like Array.join, but with a different glue for the last item
    join: (array, glue = ', ', lastGlue = ' and ') ->
        switch array.length
            when 0 then return ''
            when 1 then return array.pop()
            else
                last = array.pop()
                return array.join(glue) + lastGlue + last

    uncamelize: (s) ->
        (''+s).replace(/((?=.)[a-z])([A-Z])(?=[^A-Z])/g, '$1 $2').trim()

    upperCaseFirst: (s) ->
        return s unless s
        s[0].toUpperCase() + s.slice(1)

    # escape each of the chars in s by preceding it with escapeChar
    escape: (s, chars = '\'', escapeChar = '\\') ->
        return s if typeof s != 'string'
        s.replace new RegExp("(^|[^\\\\])([#{regexEscape chars}])",'g'), "$1#{escapeChar}$2"

    # normalises a version string to be a specifified number of points
    # e.g.
    #     normaliseVersion('1', 3) -> '1.0.0'
    #     normaliseVersion('1.2', 3) -> '1.2.0'
    #     normaliseVersion('1.2.3', 3) -> '1.2.3'
    #     normaliseVersion('1.2.3', 2) -> '1.2'
    #     normaliseVersion('1.2.3', 1) -> '1'
    #     normaliseVersion(0, 3) -> '0.0.0'
    normaliseVersion: (version, numberOfPoints = 3) ->
        n = String(version).split /\./
        return null if not n or n.length is 0

        while n.length < numberOfPoints
            n.push '0'

        return n.slice(0, numberOfPoints).join('.')

    # return true if the parameter is in the form of 0, 0.0, 0.00.00, 0.000.00.000, etc
    isNumericVersion: (s) -> !!s.match(/^\d+(\.\d+)*$/)

module.exports = stringUtils
