mongoose = require 'mongoose'
RSVP = require 'rsvp'
regexEscape = require 'escape-string-regexp'
projectSchema = require './Project'
baseSchema = require './_Base'
SubTargetMatch = require '../src/SubTargetMatch'
fuzzy = require 'fuzzy'

customerSchema = mongoose.Schema
    # Full name of the Customer
    name: String
    # Other names the customer may be known by
    aliases: [String]
    # A customer's site
    projects: [projectSchema]
    slackChannel: String

baseSchema.applyTo customerSchema

########################################################
#
# Utility methods
#

customerSchema.statics.simplifyName = (name) ->
    name.replace /\b(council|city|town|university|college|london borough|borough|district|of|[^a-z]+)\b/gi, ''
        .replace new RegExp(' {2,}'), ' '
        .trim()


########################################################
#
# Static schema methods
#

# Find by name, allowing a progressively looser match until at least one is found
# Returns a single Customer or NULL
customerSchema.statics.findOneByName = (name) ->
    @findByName(name).then (customers) -> if customers?.length then customers[0] else null

# Find by name, allowing a progressively looser match until at least one is found
# Returns an array of Customer
customerSchema.statics.findByName = (name) ->
    throw "Name is required" unless name

    @findByExactName(name)
        .then (results) => if results.length then results else @findBySingleWord(name)
        .then (results) => if results.length then results else @findByPartialName(name)
        .then (results) => if results.length then results else @findBySimplifiedName(name)
        .then (results) => if results.length then results else @findByExactName(name, 'aliases')
        .then (results) => if results.length then results else @findBySingleWord(name, 'aliases')
        .then (results) => if results.length then results else @findByPartialName(name, 'aliases')
        .then (results) => if results.length then results else @findByNameParts(name)
        .then (results) => if results.length then results else @findByNameParts(name, 'aliases')
        .then (results) =>
            return results if results.length
            # simplify the input name and run it all again!
            simplifiedName = @simplifyName name
            if simplifiedName != name
                return @findByName simplifiedName
            else
                return

# Find where the full name exactly matches the query
customerSchema.statics.findByExactName = (name, property = 'name') ->
    o = {}
    o[property] = new RegExp("^#{regexEscape(name)}$", 'i')
    @find(o).sort(name: 1)

# Find where the name contains the query as a whole word
customerSchema.statics.findBySingleWord = (name, property = 'name') ->
    o = {}
    o[property] = new RegExp("\\b#{regexEscape(name)}\\b", 'i')
    @find(o).sort(name: 1)

# Find where the name contains the query as a whole
customerSchema.statics.findByPartialName = (name, property = 'name') ->
    o = {}
    o[property] = new RegExp("#{regexEscape(name)}", 'i')
    @find(o).sort(name: 1)

# Find where the name contains each of the words in the query, in any order
customerSchema.statics.findByNameParts = (name, property = 'name') ->
    o = $and: []
    for word in name.split ' '
        expression = {}
        expression[property] = new RegExp("\\b#{regexEscape(word)}\\b", 'i')
        o['$and'].push expression
    @find(o).sort(name: 1)

# remove commonly ignored words like 'council' and 'borough'
customerSchema.statics.findBySimplifiedName = (name, property = 'name') ->
    o = {}
    o[property] = new RegExp("#{regexEscape(@simplifyName(name))}", 'i')
    @find(o).sort(name: 1)


# Finds a Customer by fuzzy matching its name and aliases
# Returns the highest scoring Customer or null if not found
customerSchema.statics.fuzzyFindOneByName = (name) ->
    # remove 's
    name = name.replace /['’]s?$/i, ''
    return new RSVP.Promise (resolve, reject) =>
        @find().then (customers) ->
            results = fuzzy.filter name, customers, extract: (customer) -> "#{customer.name} #{customer.aliases.join ' '}"
            return resolve null unless results.length

            bestMatch = score: 0
            for result in results
                bestMatch = result if result.score > bestMatch.score

            resolve bestMatch.original

customerSchema.statics.getAllNames = (forceReload) ->
    new RSVP.Promise (resolve, reject) ->
        if not forceReload and customerSchema.statics.allNames
            return resolve customerSchema.statics.allNames

        console.log 'Loading all Customer names…' if '--debug' in process.argv

        Customer = mongoose.model 'Customer', customerSchema
        Customer.find()
        .then (customers) =>

            names = []
            addUniqueName = (name) ->
                name = name.toLowerCase()
                names.push name if names.indexOf(name) is -1

            for customer in customers
                addUniqueName regexEscape(customer.name)
                addUniqueName alias for alias in customer.aliases
                addUniqueName customerSchema.statics.simplifyName(customer.name)

            # sort long -> short
            names.sort (a, b) -> b.length - a.length

            customerSchema.statics.allNames = names

            resolve names

        .catch (error) -> console.log error.stack or error

# returns a Promise which resolves to a regular expression containing all customer names and aliases
customerSchema.statics.getAllNameRegexString = (forceReload) ->
    new RSVP.Promise (resolve, reject) ->
        if not forceReload and customerSchema.statics.allNameRegexString
            return resolve customerSchema.statics.allNameRegexString

        customerSchema.statics.getAllNames(forceReload).then (names) ->
            console.log "Found #{names.length} customer names/aliases — storing regex" if '--debug' in process.argv
            customerSchema.statics.allNameRegexString = "[\"'“‘]?(#{names.join('|')})[\"'”’]?"
            resolve customerSchema.statics.allNameRegexString

# load the 'all name regex string' on connect
mongoose.connection.once 'open', (callback) -> customerSchema.statics.getAllNameRegexString(true)

# Refresh cached regex string if data is changed
customerSchema.post 'save', (doc) => customerSchema.statics.getAllNameRegexString(true)

########################################################
#
# Document methods
#

customerSchema.methods.getProject = (name = null) ->
    if name is null
        return @getDefault('projects')
    else
        regex = new RegExp "^#{regexEscape(name)}$", "i"
        return p for p in @projects when p.name.match regex

customerSchema.methods.getRepo = (id) ->
    for project in @projects
        for repo in project.repos
            return repo if repo.id is id
    return

customerSchema.methods.addAlias = (alias) ->
    @aliases.push alias if alias not in @aliases

# Returns a default single member of array property 'property'
# For projects, this is the one named 'default'
customerSchema.methods.getDefault = (property) ->
    switch property
        # special case for default project
        when 'projects'
            project = p for p in @projects when p.name is projectSchema.statics.defaultProjectName
            # return first project if 'default' one not found
            return project or @projects[0]
        else
            return baseSchema.methods.getDefault property


# Returns something that matches the start of the query
#
# @return object with properties:
#   target   the property that matched the query string
#   keywords the string found at the start of the query
#   query    the updated query, with the match removed
customerSchema.methods.findSubtarget = (query) ->
    o = baseSchema.methods.findSubtarget.call this, query
    return o if o

    # no match on property or project name, so assume it's a property of the default project
    defaultProject = @getProject()
    return if defaultProject
        new SubTargetMatch
            target: defaultProject
            keyword: ''
            property: 'project'
            query: query

    return false

########################################################
#
# Virtual properties
#

customerSchema.virtual('project', _jiri_aliasTarget: 'projects')
    .get -> @getProject()
customerSchema.virtual('alias', _jiri_aliasTarget: 'aliases')
    .get -> @aliases


module.exports = customerSchema
