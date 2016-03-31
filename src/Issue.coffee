Jira = require './Jira'
config = require '../config'
Customer = require('spatabase-customers')(config.mongo_url).model 'Customer'
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

        supportRefMatch = @summary.match /Ref:(\d{8}-\d+)/i
        if supportRefMatch
            @supportRef = supportRefMatch[1]
            @supportUrl = config.supportUrl.replace(/#\{ref\}/i, @supportRef)
            @summary = @summary.replace /\s+Ref:(\d{8}-\d+)/i, ''

    # Returns a promise that resolves to return the Customer document for this issue
    getClient: ->
        return new RSVP.Promise (resolve, reject) =>
            return resolve @client if @client
            return resolve null unless @clientName

            Customer.findOne "projects._mappingId_jira": @clientName

    isToDo: -> @status?.statusCategory?.key is "new"
    isInProgress: ->
        console.log @status.statusCategory
        return @status?.statusCategory?.key is "indeterminate"
    isDone: -> @status?.statusCategory?.key is "done"

module.exports = Issue
