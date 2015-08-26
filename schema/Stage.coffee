mongoose = require 'mongoose'

serverSchema = require './Server'
moduleSchema = require './Module'

stageSchema = mongoose.Schema
    name: String
    servers: [serverSchema]
    urls: [String]
    modules: [moduleSchema]


########################################################
#
# Document methods
#

stageSchema.methods.getServer = (role) ->
    regex = new RegExp "^#{role}$", "i"
    return s for s in @.servers when s.role.match regex

stageSchema.methods.getModule = (name) ->
    regex = new RegExp "^#{name}$", "i"
    return m for m in @.modules when m.name.match regex

module.exports = stageSchema
