ReleaseIssue = require 'jadu-jira/lib/ReleaseIssue'
DeploymentIssue = require 'jadu-jira/lib/DeploymentIssue'
config = require '../config'
converter = require 'number-to-words'
joinn = require 'joinn'
semver = require 'semver'

class IssueOutput

    VIEW_NORMAL: 1
    VIEW_CONDENSED: 2
    VIEW_EXPANDED: 3

    constructor: (@jira, @issues) ->
        throw new Error 'IssueOutput requires JIRA instance as first parameter' unless @jira?.getStatusNames
        @issues = [@issues] unless Array.isArray @issues

    lowercaseRelativeDays: (s) -> return s.replace /(yesterday|today|tomorrow|last|next)/gi, (word) -> word.toLowerCase()

    getSlackMessage: () ->
        attachments = []

        for issue in @issues
            attachment =
                "mrkdwn_in": ["text"]
                "fallback": "[#{issue.key}] #{issue.summary}"

            # Spacecraft Release ticket
            if issue.key.match(/^(SPC|SUP)-/) and issue instanceof ReleaseIssue
                text = "<#{issue.url}|#{issue.key}> *#{issue.summary}*"

                text += " `#{issue.status.name}`" if issue.status?.name

                text += "\n_Created #{@lowercaseRelativeDays issue.created.calendar()} by #{issue.creator.displayName}"

                if issue.updated.unix() != issue.created.unix()
                    text += ", updated #{@lowercaseRelativeDays issue.updated.calendar()}._"
                else
                    # need to close the italics
                    text += "_"

                for feature in issue.features
                    text += "\n  • _includes_ <#{feature.url}|#{feature.key}> #{feature.summary} `#{feature.status.name}`"

                deployments = {}
                for deployment in issue.deployments when deployment.status.name is 'Successful Deployment'
                    deployments[deployment.version] = [] unless deployments[deployment.version]
                    deployments[deployment.version].push deployment.stage

                deploymentGraph = for version, stages of deployments
                    s = "#{version} "
                    s += '-'.repeat(12 - s.length)

                    if 'QA' in stages and 'UAT' in stages and 'Production' in stages
                        s += '>☻ ---->☻ --------->☻'
                    else if 'QA' in stages and 'UAT' in stages
                        s += '>☻ ---->☻'
                    else if 'QA' in stages and 'Production' in stages
                        s += '>☻ ---------------->☻'
                    else if 'UAT' in stages and 'Production' in stages
                        s += '!?----->☻ --------->☻'
                    else if 'QA' in stages
                        s += '>☻'
                    else if 'UAT' in stages
                        s += '!?----->☻'
                    else if 'Production' in stages
                        s += '!?----------------->☻'

                if deploymentGraph.length
                    text += "\n```\n           [QA]   [UAT]   [Production]\n#{deploymentGraph.join "\n"}\n```"

            # Spacecraft Deployment ticket
            else if issue.key.match(/^(SPC|SUP)-/) and issue instanceof DeploymentIssue
                text = "<#{issue.url}|#{issue.key}>"
                status = if issue.status.name.match(/Deployment/i) then issue.status.name else "Deployment (#{issue.status.name})"

                versionMatch = issue.summary.match /(\d+\.\d+\.\d+)/
                if versionMatch and not issue.clientName and issue.stage
                    versionNumber = versionMatch[1]
                    text += " #{status} of *#{issue.clientName} #{versionNumber}* to #{issue.stage}"
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

                    if issue.cxmRef
                        text += " <#{issue.cxmUrl}|:q: #{issue.cxmRef}>"

                # Other projects
                else
                    # story points
                    switch issue.storyPoints
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

            if issue.status.name in @jira.getStatusNames('awaitingReview') and issue.mergeRequests?.length
                if issue.mergeRequests.length is 1
                    text += "\n <#{issue.mergeRequests[0].url}|Merge request>"
                else
                    text += "\n Merge requests: " +
                            joinn ("<#{mr.url}|#{mr.label}>" for mr in issue.mergeRequests)

            # display Assignee's gavatar
            if issue.assignee?.emailAddress
                Gravatar = require 'gravatar'
                attachment.author_icon = Gravatar.url issue.assignee.emailAddress, {s: 48, d: '404'}, 'https'

            attachment.text = text

            attachments.push attachment

        attachments: JSON.stringify(attachments)


module.exports = IssueOutput
