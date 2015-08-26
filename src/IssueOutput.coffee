Issue = require './Issue'

class IssueOutput

    VIEW_NORMAL: 1
    VIEW_CONDENSED: 2
    VIEW_EXPANDED: 3

    # the fields that should be requested in an api call to be processed by this class
    FIELDS: [
        'customfield_10025', # Reporting Customer
        'issuetype',
        'summary',
        'status',
        'subtasks',
        'customfield_10202',
        'customfield_12302', # Server(s)
        'customfield_10004', # Story points
        'issuelinks',
        'assignee'
    ]

    constructor: (@issues) ->
        unless @issues.length?
            @issues = [@issues]

    getSlackMessage: () ->
        attachments = []

        try
            for issue in @issues
                attachment =
                    "mrkdwn_in": ["text"]
                    "fallback": "[#{issue.key}] #{issue.summary}"

                # Spacecraft Release ticket
                if issue.key.match(/^(SPC|SUP)-/) and issue.issuetype?.name is "Release"
                    text = "<#{issue.url}|#{issue.key}>"

                    versionMatch = issue.summary.match /(\d+\.\d+)/
                    if versionMatch and not issue.client?.isEmpty()
                        versionNumber = versionMatch[1]
                        text += " *#{issue.client.name} #{versionNumber}*"
                    else
                        text += " #{issue.summary}"

                    text += " `#{issue.status.name}`" if issue.status?.name

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
                    if versionMatch and not issue.client?.isEmpty() and issue.server
                        versionNumber = versionMatch[1]
                        text += " #{status} of *#{issue.client.name} #{versionNumber}* to #{issue.server}"
                    else
                        text += " #{status} of #{issue.summary}"


                # Others
                else
                    attachment.author_name = "#{issue.key} #{issue.summary}"
                    attachment.author_link = issue.url

                    text = "#{issue.issuetype.name}"

                    # Spacecraft / Support
                    if issue.key.match /^(SPC|SUP)-/

                        unless not issue.client or issue.client.name.match /^(|\*None\*)$/
                            text += " for #{issue.client.name}"
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
            console.error "Error building Issue output: #{e}"

        "attachments": JSON.stringify(attachments)


module.exports = IssueOutput
