mongoose = require 'mongoose'

serverSchema = mongoose.Schema
    role: String
    host: String

module.exports = serverSchema
