Pattern = require '../src/Pattern'

sinon = require 'sinon'
chai = require 'chai'
chaiAsPromised = require 'chai-as-promised'
should = chai.should()
expect = chai.expect
chai.use chaiAsPromised

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
        'what platform is Bromley?'

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
        'show Maldon software'

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

config = require '../config'
craterInit = require('crater') config.mongo_url

describe 'CustomerInfoAction', ->

    ###########################
    describe 'with cold state', ->

        for own description, messages of validMessages
            describe description, ->
                for msg in messages
                    it "respond to “@jiri #{msg}”",
                        ((msg) -> ->
                            craterInit.then (customer_database) ->
                                action = new CustomerInfoAction jiri, customer_database, channel
                                expect(action.test(createMessage(msg))).to.be.ok
                        )(msg)

        describe 'misc invalid messages', ->
            for msg in invalidMessages
                it "don't respond to “@jiri #{msg}”",
                    ((msg) -> ->
                        craterInit.then (customer_database) ->
                            action = new CustomerInfoAction jiri, customer_database, channel
                            promise = action.test(createMessage(msg))
                            expect(promise).to.eventually.not.be.ok
                    )(msg)
