regexEscape = require 'escape-string-regexp'

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

module.exports = stringUtils
