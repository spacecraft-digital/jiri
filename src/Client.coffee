
class Client
    
    constructor: (reportingCustomerField) ->
        @name = reportingCustomerField.value
        @shortName = @condenseName @name
        @codename = @codenamify @name

    # attempts to make customer names shorter by removing redundant words
    condenseName: (name) ->
        name.replace /( (|council|borough|city))+$/ig, ''

    codenamify: (name) ->
        name.toLowerCase().replace(/[^a-z0-9-]+/g,'-').replace(/(^-+|-+$)/g,'')

    isEmpty: ->
        return @name.match /^(|\*None\*)$/

module.exports = Client
