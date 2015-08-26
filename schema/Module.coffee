mongoose = require 'mongoose'

moduleSchema = mongoose.Schema
    name: String
    version: String

module.exports = moduleSchema
