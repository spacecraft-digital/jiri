RSVP = require 'rsvp'
Interpretter = require './Interpretter'
Issue = require './Issue'
IssueOutput = require './IssueOutput'

class IssueInfoInterpretter extends Interpretter

    refRegex: /\b((SPC|SUP|SA)-[0-9]{3,6})/ig

    constructor: (@jiri) ->

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        refs = message.text.match @refRegex
        @channel = message.channel

        if !refs.length
            return new RSVP.Promise (resolve, reject) ->
                reject('No Jira refs in message')

        return @getJiraIssues(refs)
                .catch @errorLoadingIssues
                .then @issuesLoaded
                .catch @errorParsingIssues

    getJiraIssues: (refs) ->
        rows = []

        query = "issue in (#{refs.join(', ')})"
        fields = [
            'customfield_10025', # Reporting Customer
            'issuetype',
            'summary',
            'status',
            'subtasks',
            'customfield_10202',
            'customfield_12302', # Server(s)
            'issuelinks'
        ]

        new RSVP.Promise (resolve, reject) =>
            @jiri.jira.searchJira(
                query
                fields: fields
                (error, result) =>
                    if error
                        reject(error)
                    else
                        resolve(result)
            )

    issuesLoaded: (result) =>
        issues = []
        for issue in result.issues
            issues.push new Issue(issue)
        outputter = new IssueOutput issues
        response = outputter.getSlackMessage()
        response.channel = @channel.id
        response

    errorLoadingIssues: (error) ->
        console.error "Jira API error: #{error}"

    errorParsingIssues: (error) ->
        console.error "Jira parsing error: #{error}"

    test: (message) ->
        return message.type is 'message' and
               message.text? and
               message.channel? and
               message.text.match @refRegex

module.exports = IssueInfoInterpretter
