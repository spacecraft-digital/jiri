Jira = require './Jira'
config = require '../config'
moment = require 'moment'

# Wraps a standard Jira issue object (as returned by the API) to normalise
# some Jaduisms
class Issue

    isExtended: true

    constructor: (issueData) ->
        return unless issueData and issueData.fields?

        for own key, value of issueData
            # put 'fields' directly on issue
            if key is 'fields'
                for own key2, value2 of value
                    @[key2] = value2
            else
                @[key] = value

        @clientName = if config.jira_field_reportingCustomer then issueData.fields[config.jira_field_reportingCustomer]?[0]?.value else null
        @server = if config.jira_field_server then issueData.fields[config.jira_field_server] else null
        @url = config.jira_issueUrl.replace /#{([a-z0-9_]+)}/, (m, key) => return @[key]

        # convert dates to moments
        @created = moment @created if @created
        @updated = moment @updated if @updated

        if issueData.cxmCase
            @cxmRef = issueData.cxmCase.reference
            @cxmUrl = config.cxm_caseUrl.replace(/#\{reference\}/i, @cxmRef)

        # clean up old Support.Jadu ref if present
        @summary = @summary.replace /\s+Ref:(\d{8}-\d+)/i, ''

    isToDo: -> @status?.statusCategory?.key is "new"
    isInProgress: ->
        console.log @status.statusCategory
        return @status?.statusCategory?.key is "indeterminate"
    isDone: -> @status?.statusCategory?.key is "done"

module.exports = Issue
