RSVP = require 'rsvp'
config = require '../config'
JiraApi = require('jira').JiraApi
Customer = require('spatabase-customers')(config.mongo_url).model 'Customer'
async = require 'async'
Issue = require './Issue'
ReleaseIssue = require './ReleaseIssue'
IssueOutput = require './IssueOutput'
semver = require 'semver'
escape_quotes = require 'escape-quotes'
normalize_version = require 'normalize-version'

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

    getReleaseTicket: (project, targetVersion = 'latest') ->
        return new RSVP.Promise (resolve, reject) =>
            project.getJiraMappingId(@)
            .catch (error) ->
                reject "No Jira mapping ID available"
            .then (jiraMappingName) =>
                return reject "Sorry, I don't know what Jira knows #{project.name} as" unless jiraMappingName

                jql = "'Reporting Customers' = '#{escape_quotes jiraMappingName}' AND issueType = 'Release'"

                @search jql,
                    fields: IssueOutput.prototype.FIELDS

            .catch reject
            .then (result) =>
                try
                    isNumericVersion = !!String(targetVersion).match(/^\d+(\.\d+)*$/)
                    targetVersion = normalize_version(targetVersion, 2) if isNumericVersion

                    releases = []
                    for issue in result.issues
                        release = new ReleaseIssue issue

                        # exact match -> resolve immediately
                        if release.version is targetVersion
                            return resolve release

                        releases.push release

                    return reject "no releases found" unless releases.length

                    if isNumericVersion
                        return reject "cannot find release `#{targetVersion}` for #{customer.name}"

                    releases.sort (one, two) -> semver.rcompare(one.semver, two.semver)

                    # the most recent release, regardless of status
                    if targetVersion in ReleaseIssue.prototype.synonyms.latest
                        return resolve releases[0]
                    # the most recent completed release
                    else if targetVersion in ReleaseIssue.prototype.synonyms.previous
                        return resolve release for release in releases when release.isDone()
                    # return the latest release if it's not Done
                    else if targetVersion in ReleaseIssue.prototype.synonyms.next
                        return resolve if releases[0].isDone() then null else releases[0]
                    else
                        return reject "I don't know what a ‘#{targetVersion}’ release is"

                    reject "#{targetVersion} release not found"
                catch e
                    console.log e.stack
                    reject "something went wrong"


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