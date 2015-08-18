db = require './db'
async = require 'async'
RSVP = require 'rsvp'
Client = require './Client'

class ClientRepository
    constructor: (@jiri) ->

    find: (name, loadIfNotFound = true) =>
        return new RSVP.Promise (resolve, reject) ->
            # exact name match
            db.clients.findOne
                alias: name,
                (error, record) ->
                    if not error and record
                        resolve(record)
                    else
                        reject(error)

        .catch (error) ->
            return new RSVP.Promise (resolve, reject) ->
                # allow spaces and hyphens to be used interchangably
                name = name.replace /[- ]+/g, '[\- ]*'

                # find whole word
                db.clients.find
                    alias:
                        $regex: new RegExp '\\b' + name + '\\b', 'i'
                    (error, records) ->
                        if not error and records.length
                            if records.length is 1
                                resolve(records[0])
                            else
                                reject
                                    multipleRecords: records
                        else
                            reject(error)

        .catch (error) =>
            if loadIfNotFound
                return @load()
                    .then =>
                        return @find name, false
            else
                return null

        .then (record) ->
            return new Client record.name

    load: (callback) =>
        return new RSVP.Promise (resolve, reject) =>
            @jiri.jira.getCreateIssueMeta
                projectKeys: 'SPC'
                issuetypeNames: 'Bug'
                expandFields: true,
                (error, response) ->
                    clientNames = []
                    clientNames.push o.value for o in response.projects[0].issuetypes[0].fields[Client.prototype.CUSTOM_FIELD_NAME].allowedValues
                    resolve clientNames

        .then (clientNames) ->
            async.each(
                clientNames,
                (clientName, callback) ->
                    return if clientName is '*None*'

                    db.clients.update(
                        {
                            alias: clientName
                        },
                        {
                            name: clientName
                            alias: clientName
                        },
                        {
                            upsert: true
                        },
                        (error, num, newDoc) ->
                            callback if error then error else null
                    )
                    # values.push
                    #     name: clientName
                    #     alias: Client.prototype.condenseName clientName
                ->
                    resolve()
            )

module.exports = ClientRepository
