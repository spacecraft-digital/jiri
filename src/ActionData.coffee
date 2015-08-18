
class ActionData

    constructor: (@key, @value, ttl) ->
        @expires = Date.now() + ttl * 1000

    expired: ->
        return @expires < Date.now()

module.exports = ActionData
