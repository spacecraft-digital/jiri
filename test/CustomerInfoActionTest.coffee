Pattern = require '../src/Pattern'

chai = require 'chai'
should = chai.should()
expect = chai.expect

CustomerInfoAction = require '../src/actions/CustomerInfoAction'

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
    'Query a specific property': [
        'find Maldon projects'
        'show oxford projectManager'
        'tell me about Warrington’s Local Offer'
        'show oxford pm'
        'show oxford’s PM'
        'show the QA URL for Oxford City Council'

        # should match customer names in various abbreviations
        'show warrington borough council’s url'
        'show warrington council’s url'
        'show warrington’s url'
        'show WBC’s url'

        'find Maldon slackChannel'
        'what\'s Maldon\'s slack channel'
        'what’s Maldon’s slack channel'

        'show Maldon repo'
        'show Maldon repos'
        'show the oxford intranet state'
        'is Maldon intranet hosted by Jadu?'
        'show Maldon go live date'
        'who is Maldon\'s project manager'

        'get Maldon intranet repo url'
        'show Maldon qa server'

        'display Maldon qa versions'

        'show Maldon production server'

        'show Maldon servers'
        'show Maldon urls'
        'show Maldon modules'

        'show Oxford sites'
        'where is the UAT site for oxford?'
        'where is oxford’s UAT site?'
        'where is oxford’s UAT?'
    ]
    'Special cases': [
        'is Maldon\'s intranet live?'
        'what platform is Maldon on?'
        'who is Oxford hosted by?'
        'what CMS version is Oxford’s UAT?'
    ]
    'Calculations': [
        'is Maldon LAMP?'
    ]
}

invalidMessages = [
    'more'
    'when is the Oxford QA URL'
    'what I was wondering is what\'s oxford\'s slack channel'
    'show 3'
]

describe 'CustomerInfoAction', ->

    ###########################
    describe 'with cold state', ->

        for own description, messages of validMessages
            describe description, ->
                for msg in messages
                    it "respond to “@jiri #{msg}”",
                        ((msg) -> ->
                            action = new CustomerInfoAction jiri, channel
                            expect(action.test(createMessage(msg))).to.be.ok
                        )(msg)

        describe 'misc invalid messages', ->
            for msg in invalidMessages
                it "don't respond to “@jiri #{msg}”",
                    ((msg) -> ->
                        action = new CustomerInfoAction jiri, channel
                        expect(action.test(createMessage(msg))).to.not.be.ok
                    )(msg)

    ###########################
    describe 'when the previous query was ambiguous', ->

        ###########################
        # describe 'when received immediately after Jiri\'s previous message', ->
        #     # this will return action and message objects for when
        #     getVars = (msg) ->
        #         jiri =
        #             slack: self: id: 'jiri'
        #             getLastOutcome: ->
        #                 return {
        #                     outcome: CustomerInfoAction.prototype.OUTCOME_TRUNCATED_RESULTS
        #                     data: {}
        #                 }
        #             createPattern: (metaPattern, parts, subpartMatches = false) ->
        #                 new Pattern metaPattern, parts, subpartMatches

        #         message = createMessage(msg, false)
        #         message.channel.latest =
        #             user: 'jiri'

        #         action = new CustomerInfoAction jiri, channel

        #         [action, message]

        #     for msg in [
        #             'more'
        #             'more please'
        #             'gimme moar!'
        #             '10 more'
        #         ]
        #         it "respond to “#{msg}”",
        #             ((msg) -> ->
        #                 [action, message] = getVars msg
        #                 expect(action.test(message)).to.be.ok
        #             )(msg)

        #     for msg in [
        #             'I just can\'t take this any more'
        #             'for goodness sake just give me some more'
        #             'for goodness sake just give me some others'
        #             'foo bar baz'
        #         ]
        #         it "don't respond to “#{msg}”",
        #             ((msg) -> ->
        #                 [action, message] = getVars msg
        #                 expect(action.test(message)).to.not.be.ok
        #             )(msg)

        # ###########################
        # describe 'when someone else has sent a message since Jiri\'s previous message', ->
        #     # this will return action and message objects for when
        #     getVars = (msg) ->
        #         jiri =
        #             slack: self: id: 'jiri'
        #             getLastOutcome: ->
        #                 return {
        #                     outcome: CustomerInfoAction.prototype.OUTCOME_TRUNCATED_RESULTS
        #                     data: {}
        #                 }
        #             createPattern: (metaPattern, parts, subpartMatches = false) ->
        #                 new Pattern metaPattern, parts, subpartMatches

        #         message = createMessage(msg, false)
        #         message.channel.latest =
        #             user: 'someone_else'

        #         action = new CustomerInfoAction jiri, channel

        #         [action, message]

        #     for msg in [
        #             'jiri more'
        #             'more please jiri'
        #             'jiri, gimme moar!'
        #             'jiri: 10 more'
        #         ]
        #         it "respond to “#{msg}”",
        #             ((msg) -> ->
        #                 [action, message] = getVars msg
        #                 expect(action.test(message)).to.be.ok
        #             )(msg)

        #     for msg in [
        #             'more'
        #             '10 more'
        #             'I just can\'t take this any more'
        #             'for goodness sake just give me some more'
        #             'for goodness sake just give me some others'
        #             'foo bar baz'
        #         ]
        #         it "don't respond to “#{msg}”",
        #             ((msg) -> ->
        #                 [action, message] = getVars msg
        #                 expect(action.test(message)).to.not.be.ok
        #             )(msg)
