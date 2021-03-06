# Constructs a regex from multiple parts
#
# metaPattern
#   A regex with placeholders for 'parts'
#   The placeholders are simple words [a-z0-9_]{2,}
#
# parts
#   a hash with part name as key, and a 'subparts' hash as value
#   The subparts hash contains subpart name as key and a partial regex as value
#
# NOTE: any back slashes in parts strings need to be repeated. i.e. to achieve \s, you need to write \\s
#
# subpartMatches
#   if false, any groups within subparts will be converted to non-matching groups (?:foo)
#
class Pattern

    constructor: (@metaPattern, parts, @subpartMatches = false) ->
        @parts =
            jiri:
                _: '@?jiri[:\\-—…. ,]*'

        for own key, value of parts
            if typeof value is 'string'
                value = {_: value}
            @parts[key] = value

        @partsInOrder = []

    getPart: (i) ->
        return @partsInOrder[i]

    getParts: ->
        return @partsInOrder

    getRegexStringForPart: (s) ->
        @partsInOrder.push s
        return '' unless @parts[s]

        subparts = @parts[s]
        regex = ("(?:#{subpart})" for own key, subpart of subparts)

        unless @subpartMatches
            regex = (r.replace /\((?!\?)/g, '(?:' for r in regex)

        return if regex.length is 1 then regex[0] else "(#{regex.join('|')})"

    getRegex: ->
        new RegExp(@metaPattern
            .replace /\? /g, '?\\s*'
            # allow multiple spaces wherever one is allowed
            .replace /[ ]+(?![+*?])/g, ' +'
            .replace /(\\b|\b)([a-z0-9_]{2,})(\b|\s)/ig, (m,prefix,partName) =>
                s = prefix + @getRegexStringForPart partName
                if s then return s else return m
            # allow 'smart apostrophes'
            .replace /([a-z])'s\b/gi, "$1['’]s"
        'i')

    # Updates the 'jiri' part to allow the Slack user ID mention
    setSlack: (slack) =>
        unless @slackSet
            @parts.jiri._ = @parts.jiri._.replace /@?jiri(?!\|<@)/g, "(@?#{slack.self.name}|<@#{slack.self.id}>)"

            # allow Jiri to be mentioned in parts
            for own key, values of @parts
                continue if key is 'jiri'
                for own key2, value of values
                    @parts[key][key2] = value.replace /(\b|\\b)@?jiri(\b|\\b)/ig, "(@?#{slack.self.name}|<@#{slack.self.id}>)"

        @slackSet = true

module.exports = Pattern
