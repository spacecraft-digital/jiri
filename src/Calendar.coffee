ical = require 'ical'
config = require './../config'
Gravatar = require 'gravatar'
converter = require 'number-to-words'
moment = require 'moment'
moment.locale 'en-GB'

class Calendar

    constructor: (@jiri, @url) ->

    loadPeopleCalendar: ->
        ical.fromURL @url, {}, @peopleCalendarLoaded

    peopleCalendarLoaded: (err, response) =>
        now = moment()

        # initialise these two to fix the order
        people =
            "on holiday": []
            "working from home": []

        for own key, data of response
            for own id, event of data
                if event.summary and now.isBetween event.start, event.end
                    [...,name,type] = event.summary.match /^(.+) - (.+)$/

                    switch type
                        when 'Other Events' then type = 'working from home'
                        when 'Sick' then type = 'off sick'
                        else type = 'on ' + type.toLowerCase()

                    people[type] = [] if not people[type]

                    # add two hours to ensure it is treated as the right day
                    returnDate = moment(event.end).add('2', 'hours')

                    # consider weekend return dates to be Monday
                    switch returnDate.format('ddd')
                        when 'Sat' then returnDate.add '2', 'days'
                        when 'Sun' then returnDate.add '1', 'days'

                    people[type].push
                        name: name
                        returnDate: returnDate

        @postPeopleToSlack(people)

    postPeopleToSlack: (groups) =>
        now = moment()
        nextWeek = moment().add 7, 'days'

        for own type, people of groups
            attachments = []
            response =
                channel: config.calendarChannel

            if people.length is 0
                response.text = "No one is *#{type}* today"
            else if people.length is 1
                response.text = "There is #{converter.toWords(people.length)} person *#{type}* today:"
            else
                response.text = "There are #{converter.toWords(people.length)} people *#{type}* today:"

            people.sort (a,b) ->
                return -1 if a.name < b.name
                return 1 if a.name > b.name
                0

            for person in people
                slackUser = null
                attachment = {}
                [...,firstName,lastName] = person.name.match /^(.+) ([^ ]+)$/
                for own id, user of @jiri.slack.users
                    if user.real_name is person.name or (user.profile.last_name is lastName and firstName.indexOf(user.profile.first_name) != -1)
                        attachment.author_name = user.real_name
                        attachment.fallback = user.real_name
                        if user.profile.image_48
                            attachment.author_icon = user.profile.image_48
                        slackUser = user
                        break

                unless slackUser
                    attachment.author_name = person.name
                    attachment.fallback = person.name

                switch type
                    when 'working from home'
                        if slackUser and slackUser.profile.phone
                            attachment.text = "#{user.profile.phone}"

                    when 'on holiday'
                        returnDate = person.returnDate.calendar now, {
                            sameDay: '[later today]'
                            nextDay: '[tomorrow]'
                            nextWeek: '[on ]dddd'
                            sameElse: '[on] dddd Do MMMM'
                        }
                        if person.returnDate.isAfter nextWeek
                            returnDate = "#{person.returnDate.fromNow()} #{returnDate}"
                        attachment.text = "Back #{returnDate}"

                attachments.push attachment

            response.attachments = JSON.stringify(attachments)

            @jiri.slack.postMessage response
        console.log "Posted holidays/leave to #{config.calendarChannel}"

module.exports = Calendar
