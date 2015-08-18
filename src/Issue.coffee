Client = require './Client'
config = require './config'

# Wraps a standard Jira issue object (as returned by the API) to normalise
# some Jaduisms
class Issue
    constructor: (issueData) ->
        return unless issueData

        for own key, value of issueData
            # put 'fields' directly on issue
            if key is 'fields'
                for own key2, value2 of value
                    @[key2] = value2
            else
                @[key] = value

        if issueData.fields[Client.prototype.CUSTOM_FIELD_NAME]
            @client = new Client issueData.fields[Client.prototype.CUSTOM_FIELD_NAME].pop()
        @server = issueData.fields.customfield_12302
        @url = config.jira_issueUrl.replace /#{([a-z0-9_]+)}/, (m, key) =>
            return @[key]

        supportRefMatch = @summary.match /Ref:(\d{8}-\d+)/i
        if supportRefMatch
            @supportRef = supportRefMatch[1]
            @supportUrl = config.supportUrl.replace(/#\{ref\}/i, @supportRef)
            @summary = @summary.replace /\s+Ref:(\d{8}-\d+)/i, ''

module.exports = Issue
