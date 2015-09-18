Pattern = require '../src/Pattern'

chai = require 'chai'
should = chai.should()
expect = chai.expect

IssueSearchAction = require '../src/actions/IssueSearchAction'

channel =
    id: '123'
    name: 'somewhere'
    latest:
        user: 'user'

createMessage = (text, prefixJiri = true) ->
    ch = {}
    ch[key] = value for own key, value of channel
    return {
        type: 'message'
        text: if prefixJiri then "@jiri #{text}" else text
        channel: ch
    }

jiri =
    getLastOutcome: -> return null
    createPattern: (metaPattern, parts, subpartMatches = false) ->
        new Pattern metaPattern, parts, subpartMatches

validMessages = {
    'general': [
        'display features'
        'what are bugs'
        'what\'s the bug'
        'show us epics'
        'show me bugs'
        'show me bugs'
        'find issues'
        'get issues'
        'find outstanding issues'
        'find all bugs'
        'find all issues'
        'find remaining bugs'
    ]
    'issue types': [
        'find bugs'
        'find issues'
        'find features'
        'find releases'
        'find deployments'
        'find test items'
        'find epics'
    ]
    'statuses': [
        'find issues to do'
        'find issues to work on'
        'find issues in testing'
        'get issues to merge'
        'find features awaiting merge'
        'find issues for web dev'
        'find issues for webdev'
        'show bugs for ux'
        'find issues needing ux'
        'what are issues needing review'
        'find issues ready to review'
        'find issues in progress'
    ]
    'customer': [
        'find bugs for oxford'
        'find epics for oxford'
        'show bugs for oxford'
        'get oxford bugs'
        'find oxford epics'
        'find issues for oxford'
        'what\'s left for oxford'
    ]
    'search': [
        'find bugs for oxford containing foo'
        'find bugs for oxford with foo'
        'find bugs for oxford matching foo'
        'find all features for oxford matching “foo”'
        'find bugs for oxford containing foo bar'
        'get bugs for oxford containing "foo bar"'
        'show bugs containing foo bar for oxford'
        'find bugs containing foo for oxford'
        'find bugs to do for oxford containing foo'
        'find oxford epics containing foo'
        'find ux bugs to do for oxford containing foo'
        'find ux bugs to do   for oxford containing foo'
        'find bugs for ux for oxford containing foo'
        'find bugs ready to release for oxford'
        'find bugs ready to release for oxford like "foo"'
        'find bugs to review for oxford containing foo'
    ]
    'multi-word customer': [
        'find bugs for warrington local offer'
        'find bugs for coventry’s intranet'
    ]
    'setting the limit': [
        'show 10 issues for oxford'
        'find 20 oxford bugs'
    ]
    'specific release tickets': [
        'get release 1.2 for oxford'
        'get release 1.2.1 for oxford'
        'get latest release for warrington’s local offer'
        'get 2.4 for oxford'
        'get oxford release 2.4'
        'get oxford 2.4'
        'get coventry intranet 2.4'
        'get latest oxford release'
        'get the latest oxford release'
        'get latest oxford patch'
    ]
    'not just a Jira search — maybe Gitlab actually': [
        'get latest oxford package'
        'get the latest version for warrington’s local offer'
    ]
}

invalidMessages = [
    'show slugs for oxford'
    'foo bar bugs for oxford'
    'show 10 tissues for oxford'
    # invalid customer name (will only fail with knowledge-based regex)
    'find bugs for little paxton'

    'more'
    'more please'
    'gimme moar!'
    '10 more'
]

describe 'IssueSearchAction', ->

    ###########################
    describe 'with cold state', ->

        for own description, messages of validMessages
            describe description, ->
                for msg in messages
                    it "respond to “#{msg}”",
                        ((msg) -> ->
                            action = new IssueSearchAction jiri, channel
                            expect(action.test(createMessage(msg))).to.be.ok
                        )(msg)

        describe 'misc invalid messages', ->
            for msg in invalidMessages
                it "don't respond to “#{msg}”",
                    ((msg) -> ->
                        action = new IssueSearchAction jiri, channel
                        expect(action.test(createMessage(msg))).to.not.be.ok
                    )(msg)

    ###########################
    describe 'when truncated results have been previously returned', ->

        ###########################
        describe 'when received immediately after Jiri\'s previous message', ->
            # this will return action and message objects for when
            getVars = (msg) ->
                jiri =
                    slack: self: id: 'jiri'
                    getLastOutcome: ->
                        return {
                            outcome: IssueSearchAction.prototype.OUTCOME_TRUNCATED_RESULTS
                            data: {}
                        }
                    createPattern: (metaPattern, parts, subpartMatches = false) ->
                        new Pattern metaPattern, parts, subpartMatches

                message = createMessage(msg, false)
                message.channel.latest =
                    user: 'jiri'

                action = new IssueSearchAction jiri, channel

                [action, message]

            for msg in [
                    'more'
                    'more please'
                    'gimme moar!'
                    '10 more'
                ]
                it "respond to “#{msg}”",
                    ((msg) -> ->
                        [action, message] = getVars msg
                        expect(action.test(message)).to.be.ok
                    )(msg)

            for msg in [
                    'I just can\'t take this any more'
                    'for goodness sake just give me some more'
                    'for goodness sake just give me some others'
                    'foo bar baz'
                ]
                it "don't respond to “#{msg}”",
                    ((msg) -> ->
                        [action, message] = getVars msg
                        expect(action.test(message)).to.not.be.ok
                    )(msg)

        ###########################
        describe 'when someone else has sent a message since Jiri\'s previous message', ->
            # this will return action and message objects for when
            getVars = (msg) ->
                jiri =
                    slack: self: id: 'jiri'
                    getLastOutcome: ->
                        return {
                            outcome: IssueSearchAction.prototype.OUTCOME_TRUNCATED_RESULTS
                            data: {}
                        }
                    createPattern: (metaPattern, parts, subpartMatches = false) ->
                        new Pattern metaPattern, parts, subpartMatches

                message = createMessage(msg, false)
                message.channel.latest =
                    user: 'someone_else'

                action = new IssueSearchAction jiri, channel

                [action, message]

            for msg in [
                    'jiri more'
                    'more please jiri'
                    'jiri, gimme moar!'
                    'jiri: 10 more'
                ]
                it "respond to “#{msg}”",
                    ((msg) -> ->
                        [action, message] = getVars msg
                        expect(action.test(message)).to.be.ok
                    )(msg)

            for msg in [
                    'more'
                    '10 more'
                    'I just can\'t take this any more'
                    'for goodness sake just give me some more'
                    'for goodness sake just give me some others'
                    'foo bar baz'
                ]
                it "don't respond to “#{msg}”",
                    ((msg) -> ->
                        [action, message] = getVars msg
                        expect(action.test(message)).to.not.be.ok
                    )(msg)
