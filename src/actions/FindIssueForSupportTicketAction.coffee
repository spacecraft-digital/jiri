RSVP = require 'rsvp'
IssueInfoAction = require './IssueInfoAction'
Issue = require '../Issue'
IssueOutput = require '../IssueOutput'
ClientRepository = require '../ClientRepository'
config = require '../config'

class FindIssueForSupportTicketAction extends IssueInfoAction

    getType: ->
        return 'FindIssueForSupportTicketAction'

    describe: ->
        return 'find the Jira ticket that relates to a particular support ticket'

    getTestRegex: ->
        return new RegExp("https://support\\.jadu\\.net/jadu/support/support_ticket_details\\.php\\?headerID=(\\d+)", 'i')

    # Returns a promise that will resolve to a response if successful
    respondTo: (message) ->
        [supportTicketUrl] = message.text.match @getTestRegex()

        @setLoading()
        return @getJiraIssues "'Jadu Support Ticket' = '#{supportTicketUrl}'"

module.exports = FindIssueForSupportTicketAction
