RSVP = require 'rsvp'
Action = require './Action'
config = require '../../config'
chrono = require 'chrono-node'
moment = require 'moment'
ucfirst = require 'ucfirst'
mc_array = require 'mc-array'

class IgnoreMeAction extends Action

    constructor: (jiri, customer_database, channel) ->
        super jiri, customer_database, channel
        @ignoring = new mc_array @jiri.cache, 'ignoring-users'

    getType: ->
        return "IgnoreMeAction"

    describe: ->
        return 'tells Jiri to ignore you for a certain time period'

    getStopPatterns: ->
        [
            'jiri stop ignoring me'
        ]

    getPatterns: ->
        patterns = [
            'jiri ignore me$'
            'jiri ignore me (for) (.+)$'
            'jiri ignore me (until) (.+)$'
        ]
        patterns.push p for p in @getStopPatterns()
        patterns

    getPatternParts: ->
        'ignore': 'ignore|do not listen to|don\'t listen to'

    # if one of these matches, this Action will be run
    getTestRegex: =>
        (@jiri.createPattern(pattern, @getPatternParts()).getRegex() for pattern in @getPatterns())

    getStopRegex: =>
        (@jiri.createPattern(pattern, @getPatternParts()).getRegex() for pattern in @getStopPatterns())

    test: (message) ->
        new RSVP.Promise (resolve) =>
            return resolve false unless message.type is 'message' and message.text? and message.channel?

            resolve @isIgnored message.user
        .then (isIgnored) =>
            # if this user is ignored,
            return true if isIgnored

            for regex in @getTestRegex()
                if message.text.match regex
                    return true

            return false

    abbreviations:
        'seconds': ['s', 'sec', 'secs']
        'minutes': ['m', 'min', 'mins']
        'hours': ['h', 'hr']
        'days': ['d']
        'weeks': ['w', 'wk']
        '5': ['a few']
        '2': ['a couple']
        '15 minutes': ['a while']
        '12 hours': ['today']

    expandAbbreviations: (time) ->
        for full, abbrevs of @abbreviations
            for abbrev in abbrevs
                time = time.replace new RegExp("\\b#{abbrev}\\b", 'ig'), full
        time

    respondTo: (message) ->
        return new RSVP.Promise (resolve, reject) =>
            resolve @isIgnored message.user
        .catch -> return false
        .then (isIgnored) =>
            for regex in @getStopRegex()
                if m = message.text.toLowerCase().match regex
                    @stopIgnoring message.user
                    if isIgnored
                        return {
                            channel: @channel.id
                            text: "Sure. Hi #{message.user.profile.first_name}!"
                        }

            return if isIgnored

            for regex in @getTestRegex()
                if m = message.text.toLowerCase().match regex
                    [_, operator, time] = m
                    time = '10 minutes' unless time
                    time = @expandAbbreviations time if time
                    unless time
                        return {
                            channel: @channel.id
                            text: "Sorry, I don't understand what ‘#{time}’ is"
                        }

                    switch operator
                        when "for" then expire = chrono.parseDate "in #{time}"
                        when "until" then expire = chrono.parseDate time
                        else expire = chrono.parseDate "in 10 minutes"
                    break

            unless expire
                return {
                    channel: @channel.id
                    text: "How long is ‘#{time}’?"
                }

            # add a second to avoid being slightly less than the time requested
            m = moment(expire).add(15, 's')
            if m.diff() < 0
                return {
                    channel: @channel.id
                    text: "If only you'd told me sooner, I'd have happily ignored you until #{m.fromNow()}"
                }

            @startIgnoring message.user, m.unix()

            expireText = m.fromNow()
            if expireText.match /^in /
                expireText = expireText.replace /^in /, 'for '
            else
                expireText = "until #{expireText}"

            quips = [
                "Don't say anything interesting!"
                "I'll trust you not to say nasty things about me."
                "Catch ya later!"
                ":hear_no_evil:"
                "\n\nIt's nothing personal."
                ""
                ""
            ]
            quip = quips[Math.floor(Math.random() * quips.length)]

            texts = [
                "Sure, I'll ignore you #{expireText}. #{quip}"
                "Absolutely. Consider yourself ignored #{expireText}. #{quip}"
                "It's come to that has it? Me ignoring you #{expireText}. Very well."
                "My my, has it really come to that? Ignoring each other #{expireText}. As you wish."
                "#{ucfirst expireText}, I'm not going to listen to a word you say. #{quip}"
                "I'm going to nip off #{expireText}. Let me know if I miss anything good."
            ]
            text = texts[Math.floor(Math.random() * texts.length)]

            return {
                channel: @channel.id
                text: text
            }

    startIgnoring: (user, expiry) ->
        @ignoring.add
            userId: user.id
            expiry: expiry

    stopIgnoring: (user) ->
        toRemove = []
        @ignoring.get().then (values) =>
            # find all the objects for this user
            toRemove.push o for o in values when o.userId is user.id
            @ignoring.remove toRemove if toRemove.length

    isIgnored: (user) =>
        return new RSVP.Promise (resolve, reject) =>
            resolve @ignoring.get()
        .catch (err) =>
            console.log "Error checking if this user is being ignored", error
            return false
        .then (values) =>
            now = Math.floor(Date.now() / 1000)
            expired = []
            isIgnored = false
            # find all the objects for this user
            for o in values when o.userId is user?.id
                if o.expiry < now
                    expired.push o
                else
                    isIgnored = true
            @ignoring.remove expired if expired.length
            return isIgnored

module.exports = IgnoreMeAction
