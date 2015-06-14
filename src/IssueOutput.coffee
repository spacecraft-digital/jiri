
class IssueOutput

    VIEW_NORMAL: 1
    VIEW_CONDENSED: 2
    VIEW_EXPANDED: 3

    constructor: (@issues) ->
        unless @issues.length?
            @issues = [@issues]

    getSlackMessage: () ->
        attachments = []
        for issue in @issues

            switch issue.issuetype.name
                when "Release"
                    text = "<#{issue.url}|#{issue.key}>"

                    [m, versionNumber] = issue.summary.match /(\d\.\d)/
                    if versionNumber and not issue.client.isEmpty()
                        text += "#{issue.client.name} #{versionNumber}"
                    else
                        text += "#{issue.summary}"

                    text += " `#{issue.status.name}`"

                when "Deployment"
                    text = "<#{issue.url}|#{issue.key}>"
                    status = if issue.status.name.match(/Deployment/i) then issue.status.name else "Deployment (#{issue.status.name})"

                    [m, versionNumber] = issue.summary.match /(\d\.\d\.\d)/
                    if versionNumber and not issue.client.isEmpty() and issue.server
                        text += " #{status} of *#{issue.client.name} #{versionNumber}* to #{issue.server}"
                    else
                        text += " #{status} of #{issue.summary}"

                else
                    text = """<#{issue.url}|#{issue.key}> #{issue.summary}
                            #{issue.issuetype.name}"""
                    unless issue.client.name.match /^(|\*None\*)$/
                        text += " for #{issue.client.name}"
                    text += " `#{issue.status.name}`"

            attachments.push
                "mrkdwn_in": ["text"]
                "fallback": "[#{issue.key}] #{issue.summary}"
                "text": text

        "attachments": JSON.stringify(attachments)


module.exports = IssueOutput
