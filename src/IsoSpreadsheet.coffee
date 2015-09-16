config = require '../config'
RSVP = require 'rsvp'
async = require 'async'
GoogleSpreadsheet = require 'google-spreadsheet'
mongoose = require '../database_init'

Customer = mongoose.model 'Customer'
Project = mongoose.model 'Project'
Stage = mongoose.model 'Stage'
Module = mongoose.model 'Module'

class IsoSpreadsheet

    constructor: (mongoose) ->
        @sheet = new GoogleSpreadsheet config.isoSpreadsheetId
        credentials =
            client_email: config.google_client_email
            private_key: config.google_private_key

        @authPromise = new RSVP.Promise (resolve, reject) =>
            @sheet.useServiceAccountAuth credentials, (error) ->
                if error then reject error
                else resolve()
        .catch (err) ->
            throw "Failed to authenticate for Google Spreadsheet: #{err}"

    importData: ->
        @authPromise.then @requestRows

    requestRows: =>
        new RSVP.Promise (resolve, reject) =>
            @sheet.getRows 1, # first worksheet
                    start: 1,          # start index
                    num: 500,              # number of rows to pull
                    orderby: 'title'  # column to order results by
                , @rowsLoaded

    rowsLoaded: (err, rows) =>
        new RSVP.Promise (resolve, reject) =>
            async.mapSeries rows, (row, callback) =>
                [..., row.title, brackets] = row.title.match /^(.+?)\s*(?:(?:\(|[\-—–]\s+)(.+?)\)?\s*)?$/i

                row.projectName = Project.defaultProjectName
                row.titleAliases = []

                # handle the word 'intranet' at the end of the title
                if row.title.match /\s+intranet$/i
                    row.projectName = 'Intranet'
                    row.titleAliases.push row.title
                    row.title = row.title.replace /\s+intranet$/i, ''

                # if the brackets contain the full name and the title is an ancronym
                if brackets and brackets.match(/\s+/) and row.title.match(/^[A-Zo]+$/)
                    row.titleAliases.push row.title
                    row.title = brackets
                    brackets = null

                if brackets
                    switch brackets?.toLowerCase()
                        when 'london borough of', 'royal borough of', 'the'
                            row.titleAliases.push "#{brackets} #{row.title}"
                            row.titleAliases.push "#{row.title} (#{brackets})"
                        when 'pre go live', 'new'
                        else
                            row.projectName = brackets.charAt(0).toUpperCase() + brackets.slice(1)

                Project.findOne mappingId_isoSpreadsheet: row.title
                    .then @curryOnFindMapping row
                    .then (customer) ->
                        callback null, customer
                    .catch (error) ->
                        console.error error.stack
                        callback()

            , (error, customers) ->
                reject error if error
                resolve customers

    # this function curries row
    curryOnFindMapping: (row) ->
        (customer) =>
            new RSVP.Promise (resolve, reject) =>
                if customer
                    return @importRow row, customer
                else
                    return Customer.findByName row.title
                        .then @curryOnFindCustomer row
                        .then resolve

    # this function curries row
    curryOnFindCustomer: (row) ->
        (customers) =>
            if customers.length
                return @importRow row, customers[0]
            else
                return @importNewCustomer row

    importRow: (row, customer) ->
        new RSVP.Promise (resolve, reject) =>
            # preserve the exact title for matching on re-import
            customer.mappingId_isoSpreadsheet = row.title

            customer.aliases.push alias for alias in row.titleAliases when alias not in customer.aliases

            # if there are non-alphanumeric characters in the title, add an alias without
            normalizedName = row.title.replace(/[^a-z0-9 \-]+/ig, '').replace(/[\-_]+/g, ' ')
            customer.addAlias normalizedName if normalizedName != row.title

            # add simplified name as alias
            simplifiedName = Customer.simplifyName(row.title)
            customer.addAlias simplifiedName if simplifiedName != row.title

            # add simplified name as alias
            andAsWord = row.title.replace / & /, ' and '
            customer.addAlias andAsWord if andAsWord != row.title

            project = customer.getProject(row.projectName) or new Project name: row.projectName

            project.platform = row.platform
            project.hostedByJadu = row.hostedbyjadu.toLowerCase() not in ['no', '']

            # Live Stage
            if row.liveserver
                @importStage project, 'Production', row.liveserver, row.website,
                    CMS: row.cmsversion
                    Client: row.livesitecustomerreleaseversion
                    XFP: row.xfpversion

            # UAT Stage
            if row.uatserver
                @importStage project, 'UAT', row.uatserver, row.supporteduatsite,
                    CMS: row.supporteduatsitecmsversion
                    Client: row.supporteduatsitecustomerreleaseversion

            # QA Stage
            if row.qaserver
                @importStage project, 'QA', row.qaserver, row.qaserversite,
                    CMS: row["qaserversitecmsversion."]
                    Client: row["qaserversitecustomerreleaseversion."]

            customer.projects.push project if project.isNew

            customer.save (error, object) ->
                return reject error if error
                console.log "#{object?.name} imported"
                resolve object

    importStage: (project, stageName, servers, urls, versions) ->
        stage = project.getStage(stageName) or new Stage name: stageName

        urls = [urls] if typeof urls is 'string'
        for url in urls
            if url not in stage.urls and url.toLowerCase() not in ['-','','n/a']
                stage.urls.push url

        servers = web: servers if typeof servers is 'string'
        for role, host of servers
            stage.servers.push role: role, host: host unless stage.getServer(role)

        for module, version of versions when version
            existingModule = stage.getModule(module)
            if existingModule
                existingModule.version = version
            else
                stage.modules.push name: module, version: version

        project.stages.push stage if stage.isNew

    importNewCustomer: (row) ->
        customer = new Customer
            name: row.title

        @importRow row, customer


module.exports = IsoSpreadsheet
