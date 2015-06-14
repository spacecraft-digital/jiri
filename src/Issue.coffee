Client = require './Client'
config = require './config'

# Wraps a standard Jira issue object (as returned by the API) to normalise
# some Jaduisms
class Issue
    constructor: (issueData) ->
        for own key, value of issueData
            # put 'fields' directly on issue
            if key is 'fields'
                for own key2, value2 of value
                    @[key2] = value2
            else
                @[key] = value
        @client = new Client if issueData.fields.customfield_10025 then issueData.fields.customfield_10025.pop() else null
        @server = issueData.fields.customfield_12302
        @url = config.jira_issueUrl.replace /#{([a-z0-9_]+)}/, (m, key) =>
            return @[key]

module.exports = Issue
