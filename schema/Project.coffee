mongoose = require 'mongoose'

customerSchema = require './Customer'
repositorySchema = require './Repository'
stageSchema = require './Stage'

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

    # exact names used in different data sources
    # These are used when re-importing data, to match to
    # existing records
    name_isoSpreadsheet: String
    name_goLivesSheet: String
    name_gitlab: String
    name_jira: String

########################################################
#
# Document methods
#

projectSchema.methods.getStage = (stage) ->
    regex = new RegExp "^#{stage}$", "i"
    return s for s in @.stages when s.name.match regex


module.exports = projectSchema
