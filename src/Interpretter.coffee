

class Interpretter

    constructor: (message) ->

    respondTo: ->
        throw 'Interpretter subclass needs to implement respondTo method'

    test: ->
        throw 'Interpretter subclass needs to implement test method'

module.exports = Interpretter
