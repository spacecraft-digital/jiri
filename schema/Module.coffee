mongoose = require 'mongoose'

moduleSchema = mongoose.Schema
    name: String
    version: String

(require './_Base').applyTo moduleSchema

module.exports = moduleSchema
