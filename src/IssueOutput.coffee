Issue = require './Issue'
config = require '../config'

class IssueOutput

    VIEW_NORMAL: 1
    VIEW_CONDENSED: 2
    VIEW_EXPANDED: 3

    # the fields that should be requested in an api call to be processed by this class
    FIELDS: [
        config.jira_field_reportingCustomer, # Reporting Customer
        'issuetype',
        'summary',
        'status',
        'subtasks',
        'customfield_10202',
        config.jira_field_story_points, # Story points
        config.jira_field_server,
        config.jira_field_deployment_version,
        config.jira_field_release_version,
        'issuelinks',
        'assignee',
        'creator', # AKA reporter
        'created',
        'updated'
    ]

    constructor: (issues) ->
        @issues = []

        unless issues.length?
            issues = [issues]

        for issue in issues
            issue = new Issue issue unless issue.isExtended
            @issues.push issue

    lowercaseRelativeDays: (s) -> return s.replace /(yesterday|today|tomorrow|last|next)/gi, (word) -> word.toLowerCase()

    getSlackMessage: () ->
        attachments = []

        try
            for issue in @issues
                attachment =
                    "mrkdwn_in": ["text"]
                    "fallback": "[#{issue.key}] #{issue.summary}"

                # Spacecraft Release ticket
                if issue.key.match(/^(SPC|SUP)-/) and issue.issuetype?.name is "Release"
                    text = "<#{issue.url}|#{issue.key}> *#{issue.summary}*"

                    text += " `#{issue.status.name}`" if issue.status?.name

                    text += "\n_Created #{@lowercaseRelativeDays issue.created.calendar()}, updated #{@lowercaseRelativeDays issue.updated.calendar()}._"

                    for link in issue.issuelinks
                        linkedIssue = new Issue link.inwardIssue||link.outwardIssue
                        if link.type.inward is 'is blocked by'
                            link.type.inward = 'includes'
                        text += "\n  • _#{link.type.inward}_ <#{linkedIssue.url}|#{linkedIssue.key}> #{linkedIssue.summary} `#{linkedIssue.status.name}`"

                # Spacecraft Deployment ticket
                else if issue.key.match(/^(SPC|SUP)-/) and issue.issuetype.name is "Deployment"
                    text = "<#{issue.url}|#{issue.key}>"
                    status = if issue.status.name.match(/Deployment/i) then issue.status.name else "Deployment (#{issue.status.name})"

                    versionMatch = issue.summary.match /(\d+\.\d+\.\d+)/
                    if versionMatch and not issue.clientName and issue.server
                        versionNumber = versionMatch[1]
                        text += " #{status} of *#{issue.clientName} #{versionNumber}* to #{issue.server}"
                    else
                        text += " #{status} of #{issue.summary}"


                # Others
                else
                    attachment.author_name = "#{issue.key} #{issue.summary}"
                    attachment.author_link = issue.url

                    text = "#{issue.issuetype.name}"

                    # Spacecraft / Support
                    if issue.key.match /^(SPC|SUP)-/

                        unless issue.clientName?.match /^(|\*None\*)$/
                            text += " for #{issue.clientName}"
                        text += " `#{issue.status.name}`"

                        if issue.supportRef
                            text += " <#{issue.supportUrl}|#{issue.supportRef}>"

                    # Other projects
                    else
                        # story points
                        switch issue.customfield_10004
                            when 1 then text += " :one:"
                            when 2 then text += " :two:"
                            when 3 then text += " :three:"
                            when 4 then text += " :four:"
                            when 5 then text += " :five:"
                            when 6 then text += " :six:"
                            when 7 then text += " :seven:"
                            when 8 then text += " :eight:"
                            when 9 then text += " :nine:"
                            when 10 then text += " :keycap_ten:"

                        text += " `#{issue.status.name}`"

                # display Assignee's gavatar
                if issue.assignee?.emailAddress
                    Gravatar = require 'gravatar'
                    attachment.author_icon = Gravatar.url issue.assignee.emailAddress, {s: 48, d: '404'}, 'https'

                attachment.text = text

                attachments.push attachment

        catch e
            console.error "Error building Issue output: #{e}", e.stack

        "attachments": JSON.stringify(attachments)


module.exports = IssueOutput
