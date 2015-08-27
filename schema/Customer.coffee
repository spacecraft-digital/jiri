mongoose = require 'mongoose'
RSVP = require 'rsvp'
projectSchema = require './Project'
regexEscape = require 'escape-string-regexp'

customerSchema = mongoose.Schema
    # Full name of the Customer
    name: String
    # Other names the customer may be known by
    aliases: [String]
    # A customer's site
    projects: [projectSchema]
    slackChannel: String

    primaryProjectName: String

########################################################
#
# Utility methods
#

customerSchema.statics.simplifyName = (name) ->
    name.replace /\b(council|city|town|university|college|london borough|borough|district|of)\b/gi, ''
        .replace new RegExp(' {2,}'), ' '
        .replace /(^\s+|\s+$)/, ''


########################################################
#
# Static schema methods
#

# Find by name, allowing a progressively looser match until at least one is found
customerSchema.statics.findByName = (name) ->
    @findByExactName(name)
        .then (results) => if results.length then results else @findBySingleWord(name)
        .then (results) => if results.length then results else @findByPartialName(name)
        .then (results) => if results.length then results else @findBySimplifiedName(name)
        .then (results) => if results.length then results else @findByExactName(name, 'aliases')
        .then (results) => if results.length then results else @findBySingleWord(name, 'aliases')
        .then (results) => if results.length then results else @findByPartialName(name, 'aliases')

# Find where the full name exactly matches the query
customerSchema.statics.findByExactName = (name, property = 'name') ->
    o = {}
    o[property] = new RegExp("^#{regexEscape(name)}$", 'i')
    @find o

# Find where the name contains the query
customerSchema.statics.findBySingleWord = (name, property = 'name') ->
    o = {}
    o[property] = new RegExp("\\b#{regexEscape(name)}\\b", 'i')
    @find o

# Find where the name contains the query
customerSchema.statics.findByPartialName = (name, property = 'name') ->
    o = {}
    o[property] = new RegExp("#{regexEscape(name)}", 'i')
    @find o

# remove commonly ignored words like 'council' and 'borough'
customerSchema.statics.findBySimplifiedName = (name, property = 'name') ->
    o = {}
    o[property] = new RegExp("#{regexEscape(@simplifyName(name))}", 'i')
    @find o

########################################################
#
# Document methods
#


customerSchema.methods.getProject = (name = 'Website') ->
    regex = new RegExp "^#{regexEscape(name)}$", "i"
    return p for p in @projects when p.name.match regex


module.exports = customerSchema
