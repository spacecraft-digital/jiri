ical = require 'ical'
moment = require 'moment-timezone'

class Cron

    callbacks: []

    # frequency  int  How often (in seconds) to check the time polls and potentially fire callbacks
    constructor: (@frequency = 10) ->
        @start()

    # Takes a Date object, returns an HH:MM string
    formatTimeString: (date) ->
        return moment(date).format('HH:mm')

    # Converts a time string from an arbitrary time zone to server time
    convertToServerTime: (timeString, startZone = "Europe/London") ->
        [...,hours,minutes] = timeString.match /^(\d+):(\d+)$/
        throw "Time format must be HH:MM" unless hours and minutes

        moment.tz(startZone).hour(hours).minute(minutes).local().format('HH:mm')

    start: ->
        @pollTimer = setInterval @poll, @frequency

    stop: ->
        clearInterval @pollTimer

    poll: =>
        timeString = @formatTimeString new Date

        # only run once per minute
        return if @lastTimePolled is timeString
        @lastTimePolled = timeString

        for callback in @callbacks
            if timeString in callback.times
                callback.callback()

    ##
    # Register a function to fire at the given times of date
    # string|Array times     single string, or array of, HH:MM time strings. Times are in server timezone (probably UTC)
    # function     callback
    #
    at: (times, callback) =>
        unless typeof callback is 'function'
            throw "Cron callback must be a function"

        # ensure times is an array
        if typeof times is 'string'
            times = [times]

        @callbacks.push
            callback: callback
            times: times

module.exports = Cron
