
class Client
    CUSTOM_FIELD_NAME: 'customfield_10025'

    constructor: (reportingCustomerField) ->
        if typeof reportingCustomerField is 'string'
            @name = reportingCustomerField
        else
            @name = if reportingCustomerField? then reportingCustomerField.value else ''
        @shortName = @condenseName @name
        @codename = @codenamify @name

    # attempts to make customer names shorter by removing redundant words
    condenseName: (name) ->
        name.replace /(^(london borough of )|( (|council|borough|city))+$)/ig, ''

    codenamify: (name) ->
        name.toLowerCase().replace(/[^a-z0-9-]+/g,'-').replace(/(^-+|-+$)/g,'')

    isEmpty: =>
        return @name.match /^(|\*None\*)$/

module.exports = Client
