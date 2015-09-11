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
    mappingId_isoSpreadsheet: String
    mappingId_goLivesSheet: String
    mappingId_jira: String

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

projectSchema.methods.toString = ->
    bits = [
        "#{@name} project (#{@state} —"
    ]
    productionStage = @getStage 'production'

# Returns a default single member of array property 'property'
# For projects, this is the one named 'default'
projectSchema.methods.getDefault = (property) ->
    switch property
        when 'stages' then return @getStage 'production'
        else return baseSchema.methods.getDefault.call this, property

# Returns something that matches the start of the query
#
# @return object with properties:
#   target   the property that matched the query string
#   keywords the string found at the start of the query
#   query    the updated query, with the match removed
projectSchema.methods.findSubtarget = (query) ->
    o = baseSchema.methods.findSubtarget.call this, query
    return o if o

    # look for project by name
    for stage in @stages
        m = query.match new RegExp("^(#{stage.getNameRegexString()})\\b\\s*", 'i')
        return if m
            new SubTargetMatch
                target: stage
                keyword: m[0]
                property: 'stages'
                query: query.replace m[0], ''

    return false

# allow names to be aliased
projectSchema.methods.getNameRegexString = ->
    names = [regexEscape(@name)]
    switch @name.toLowerCase()
        when projectSchema.statics.defaultProjectName
            names.push 'main'
            names.push 'internet'
            names.push 'cms'
            names.push '1\\.12'
            names.push '(main )?website'

    return "(#{names.join('|')})(?: project)?"

########################################################
#
# Virtuals
#

# projectSchema.virtual('url').get -> @getDefault('stages').url
projectSchema.virtual('repo')
    .get -> @getDefault 'repos'
    .set (value) ->

projectSchema.virtual('pm')
    .get -> @projectManager
    .set (value) ->
        @projectManager = value
        @markModified 'projectManager'

module.exports = projectSchema
