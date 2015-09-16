mongoose = require 'mongoose'
regexEscape = require 'escape-string-regexp'

serverSchema = mongoose.Schema
    role: String
    host: String

(require './_Base').applyTo serverSchema

serverSchema.methods.getName = (forceNoun = false) -> if forceNoun then "#{@role} server" else @role
serverSchema.methods.getNameProperty = -> 'role'

serverSchema.methods.getNameRegexString = -> return "#{@role}(?: server)?"

module.exports = serverSchema
