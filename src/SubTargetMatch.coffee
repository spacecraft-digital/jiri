
class SubTargetMatch

    constructor: (options) ->
        {@target, @keyword, @query, @property, @label} = options
        for p in ['target', 'keyword', 'query', 'property']
            throw "SubTargetMatch.#{p} is required" unless p?

module.exports = SubTargetMatch
