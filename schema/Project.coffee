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


########################################################
#
# Document methods
#

projectSchema.methods.getStage = (stage) ->
    regex = new RegExp "^#{stage}$", "i"
    return s for s in @.stages when s.name.match regex


module.exports = projectSchema
