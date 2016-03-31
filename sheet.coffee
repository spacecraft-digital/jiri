Customer = require('spatabase-customers')(config.mongo_url).model 'Customer'
IsoSpreadsheet = require './src/IsoSpreadsheet'

if 'find' in process.argv
    query = process.argv[process.argv.indexOf('find')+1]
    unless query
        console.log "Please specify a customer name to search for"
        return
    console.log "Find #{query}"

    Customer.findByName query
        .then (results) ->
            console.log "\nSearch results:"
            console.log "  #{result.name} #{result.projects[0].name}" for result in results
            console.log "  none" unless results.length

            if results.length is 1
                console.log results[0]

else if 'empty' in process.argv
    Customer.remove {}, (error, response) ->
        if error
            console.log "Error: #{error}"
        else if response.result.ok
            console.log "#{response.result.n} customers removed"
        else
            console.log response

else if 'list' in process.argv
    Customer.find().then (customers) ->
        unless customers.length then console.log "No customers"
        for customer in customers
            console.log "#{customer.name} has #{customer.projects.length} project(s): #{customer.projects.map((p)->p.name).join(', ')}"

else if 'import' in process.argv
    isoSpreadsheet = new IsoSpreadsheet
    console.log "Importing data from ISO spreadsheet…"
    isoSpreadsheet.importData()
        .then (customers) ->
            console.log "#{customer.name} saved" for customer in customers

else if 'url'
    query = process.argv[process.argv.indexOf('find')+1]
    unless query
        console.log "Please specify a customer name to search for"
        return

    Customer.findByName query
        .then (results) ->
            console.log "\nSearch results:"
            console.log "  #{result.name} #{result.projects[0].name}" for result in results
            console.log "  none" unless results.length

            if results.length is 1
                console.log results[0]

else
    console.log "No command specified"
