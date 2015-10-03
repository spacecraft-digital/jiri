RSVP = require 'rsvp'
config = require '../config'
JiraApi = require('jira').JiraApi
mongoose = require '../database_init'
Customer = mongoose.model 'Customer'
async = require 'async'
stringUtils = require './utils/string'
Issue = require './Issue'
semver = require 'semver'

class Jira

    constructor: (config) ->
        @api = new JiraApi(
            config.jira_protocol,
            config.jira_host,
            config.jira_port,
            config.jira_user,
            config.jira_password,
            'latest',
            true
        )

    # Mapping the Jira callback to a promise resolution/rejection
    _getCallback: (resolve, reject) ->
        (error, response) ->
            return reject error if error
            resolve response

    ###########
    # GET
    ###########

    findIssue: (issueNumber) =>
        return new RSVP.Promise (resolve, reject) =>
            @api.findIssue issueNumber, @_getCallback(resolve,reject)

    listProjects: =>
        return new RSVP.Promise (resolve, reject) =>
            @api.listProjects @_getCallback(resolve,reject)

    getProject: (project) =>
        return new RSVP.Promise (resolve, reject) =>
            @api.getProject project, @_getCallback(resolve,reject)

    search: (jql, options) =>
        return new RSVP.Promise (resolve, reject) =>
            @api.searchJira jql, options, @_getCallback(resolve,reject)

    searchUsers: (username, startAt, maxResults, includeActive, includeInactive) =>
        return new RSVP.Promise (resolve, reject) =>
            @api.searchUsers username, startAt, maxResults, includeActive, includeInactive, @_getCallback(resolve,reject)

    listIssueTypes: =>
        return new RSVP.Promise (resolve, reject) =>
            @api.listIssueTypes @_getCallback(resolve,reject)

    ###########
    # SET
    ###########

    addNewIssue: (issue) =>
        return new RSVP.Promise (resolve, reject) =>
            @api.addNewIssue issue, @_getCallback(resolve,reject)

    updateIssue: (issueNum, issueUpdate) =>
        return new RSVP.Promise (resolve, reject) =>
            @api.updateIssue issueNum, issueUpdate, @_getCallback(resolve,reject)

    createLink: (from, to, type = 'Blocks') =>
        return new RSVP.Promise (resolve, reject) =>
            options =
                linkType: type
                fromIssueKey: from
                toIssueKey: to
            @api.issueLink options, @_getCallback(resolve,reject)

    addComment: (issueId, comment) =>
        return new RSVP.Promise (resolve, reject) =>
            @api.addComment issueId, comment, @_getCallback(resolve,reject)

    ##########
    # Integrated methods
    ##########

    _normaliseVersion: (version) ->
        n = String(version).split /\./
        switch n.length
            # 4 points must be a core product: CMS/XFP/etc
            when 4
                return false
            when 2
                n.push '0'
            when 1
                n.push '0'
                n.push '0'
        console.log version, 'becomes', n
        return n.join '.'

    getReleaseTicket: (project, targetVersion = 'latest') ->
        return new RSVP.Promise (resolve, reject) =>
            project.getJiraMappingId(@)
            .catch (error) ->
                reject "No Jira mapping ID available"
            .then (jiraMappingName) =>
                return reject "Sorry, I don't know what Jira knows #{project.fullName} as" unless jiraMappingName

                jql = "'Reporting Customers' = '#{stringUtils.escape jiraMappingName}' AND issueType = 'Release'"

                @search jql,
                    fields: ['summary',config.jira_field_release_version,'status']

            .catch reject
            .then (result) =>
                try
                    latestVersion = @_normaliseVersion 0
                    latestRelease = null
                    for issue in result.issues
                        version = issue.fields[config.jira_field_release_version]?[0]
                        unless version
                            m = issue.fields.summary.match /\s(\d+\.\d+)/
                            version = m[1] if m

                        continue unless version
                        version = @_normaliseVersion version

                        # A version of x.x.x.x is a non-customer project
                        continue if version is false

                        # need to add a patch number for the semver comparision
                        if targetVersion is 'latest' and semver.gt(version, latestVersion)
                            latestVersion = version
                            latestRelease = issue
                        else if version is targetVersion
                            return resolve new Issue(issue)

                    if targetVersion is 'latest' and latestRelease
                        return resolve new Issue(latestRelease)

                    reject "#{targetVersion} release not found"
                catch e
                    reject e.stack


    getReportingCustomerValues: ->
        return new RSVP.Promise (resolve, reject) =>
            return resolve @reportingCustomerValues if @reportingCustomerValues

            @api.getCreateIssueMeta
                # filter to just SPC bugs to reduce amount of data returned
                projectKeys: 'SPC'
                issuetypeNames: 'Bug'
                expandFields: true,
                (error, response) =>
                    return reject error if error
                    @reportingCustomerValues = []
                    @reportingCustomerValues.push o.value for o in response.projects[0].issuetypes[0].fields[config.jira_field_reportingCustomer].allowedValues when o.value != '*None*'
                    resolve @reportingCustomerValues

    # attempts to assign each of the Reporting Customer values from Jira onto a Customer document
    loadReportingCustomerValues: ->
        return new RSVP.Promise (resolve, reject) =>
            @getReportingCustomerValues()
            .then (jiraCustomerNames) ->
                console.log "I've got #{jiraCustomerNames.length} customer names from Jira"
                async.mapSeries jiraCustomerNames, (jiraCustomerName, callback) =>
                    Customer.findOneByName jiraCustomerName
                    .then (customer) ->
                        try
                            unless customer
                                console.log "Customer not found for #{jiraCustomerName}"
                                return callback null, null
                            project = null
                            for p in customer.projects
                                if p._mappingId_jira is jiraCustomerName
                                    # console.log "#{jiraCustomerName} is already set on #{customer.name}"
                                    return callback null, null
                                if !p._mappingId_jira
                                    project = p
                                    break
                            unless project
                                console.log "No projects found for #{customer.name} that don't have a Jira mapping name, so no where to put #{jiraCustomerName}"
                                return callback null, null
                            project._mappingId_jira = jiraCustomerName
                            customer.save (error, customer) ->
                                if error
                                    console.log "Error saving customer: #{error}"
                                    return callback null, null
                                callback null, customer
                        catch e
                            console.log e.stack
                , (error, values) ->
                    if error
                        console.log "Error: #{error}"
                        return reject error
                    realValues = (value for value in values when value?)
                    console.log "#{realValues.length} customers saved"
                    resolve realValues.length

module.exports = Jira