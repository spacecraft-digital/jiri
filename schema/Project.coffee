RSVP = require 'rsvp'
mongoose = require 'mongoose'
regexEscape = require 'escape-string-regexp'
SubTargetMatch = require '../src/SubTargetMatch'

customerSchema = require './Customer'
repositorySchema = require './Repository'
stageSchema = require './Stage'
baseSchema = require './_Base'

projectSchema = mongoose.Schema
    _creator:
        type: mongoose.Schema.Types.ObjectId
        ref: customerSchema
    name: String
    repos: [repositorySchema]
    stages: [stageSchema]
    notes: String
    state: String # project, live, archived
    hostedByJadu: Boolean
    platform: String # LAMP, WISP, WINS
    goLiveDate: Date
    slackChannel: String
    projectManager: String

    # exact IDs/names used in different data sources
    # These are used when re-importing data, to match to
    # existing records
    _mappingId_isoSpreadsheet: String
    _mappingId_goLivesSheet: String
    _mappingId_jira: String

baseSchema.applyTo projectSchema

projectSchema.statics.defaultProjectName = 'default'

########################################################
#
# Document methods
#

projectSchema.methods.getName = (forceNoun = false) ->
    if @name is projectSchema.statics.defaultProjectName
        return 'main project'
    else if forceNoun
        return "#{@name} project"
    else
        return @name

projectSchema.methods.getStage = (stage) ->
    regex = new RegExp "^#{stage}$", "i"
    return s for s in @.stages when s.name.match regex

# Returns a default single member of array property 'property'
# For projects, this is the one named 'default'
projectSchema.methods.getDefault = (property) ->
    switch property
        when 'stages' then return @getStage 'production'
        else return baseSchema.methods.getDefault.call this, property

# allow names to be aliased
projectSchema.methods.getNameRegexString = ->
    names = [regexEscape(@name)]
    switch @name.toLowerCase()
        when projectSchema.statics.defaultProjectName
            names.push 'main'
            names.push 'internet'
            names.push '1\\.12'
            names.push '(main )?website'

    return "(#{names.join('|')})"

###
 # Get the Jira mapping ID for this project
 # Returns a promise that resolves to the mapping ID (i.e. Reporting Customers string)
 # If the value is null, these values will be imported from Jira first.
 # @param  {Jira} jira    Instance of Jira class
 # @return Promise
###
projectSchema.methods.getJiraMappingId = (jira) ->
    throw "getJiraMappingId requires a Jira instance as the first parameter" unless jira?.loadReportingCustomerValues
    return new RSVP.Promise (resolve, reject) =>
        return resolve @_mappingId_jira if @_mappingId_jira != null
        # import values from Jira and try again
        jira.loadReportingCustomerValues().then @getJiraMappingId jira

########################################################
#
# Virtuals
#

projectSchema.virtual('repo', _jiri_aliasTarget: 'repos')
    .get -> @getDefault 'repos'

projectSchema.virtual('stage', _jiri_aliasTarget: 'stages')
    .get -> @stages
    .set (sites) ->
        @stages = sites
        @markModified 'stages'

projectSchema.virtual('site', _jiri_aliasTarget: 'stages')
    .get -> @stages
    .set (sites) ->
        @stages = sites
        @markModified 'stages'

projectSchema.virtual('sites', _jiri_aliasTarget: 'stages')
    .get -> @stages
    .set (sites) ->
        @stages = sites
        @markModified 'stages'

projectSchema.virtual('goLive', _jiri_aliasTarget: 'goLiveDate')
    .get -> @goLiveDate
    .set (value) -> @goLiveDate = value

projectSchema.virtual('hostedAtJadu', _jiri_aliasTarget: 'hostedByJadu')
    .get -> @hostedByJadu
    .set (value) -> @hostedByJadu = value

projectSchema.virtual('hostedByUs', _jiri_aliasTarget: 'hostedByJadu')
    .get -> @hostedByJadu
    .set (value) -> @hostedByJadu = value

projectSchema.virtual('pm', _jiri_aliasTarget: 'projectManager')
    .get -> @projectManager
    .set (value) ->
        @projectManager = value
        @markModified 'projectManager'

module.exports = projectSchema
