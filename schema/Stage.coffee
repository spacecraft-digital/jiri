mongoose = require 'mongoose'

serverSchema = require './Server'
moduleSchema = require './Module'
regexEscape = require 'escape-string-regexp'

stageSchema = mongoose.Schema
    name: String
    servers: [serverSchema]
    urls: [String]
    modules: [moduleSchema]

    # e.g. SSH, VPN, RDP
    accessMethod: String

(require './_Base').applyTo stageSchema

########################################################
#
# Document methods
#
#
stageSchema.methods.getName = (forceNoun = false) ->
    switch @name.toLowerCase()
        when 'qa' then name = 'QA'
        when 'uat' then name = 'UAT'
        else name = @name.toLowerCase()

    if forceNoun then "#{name} site" else name

stageSchema.methods.getServer = (role) ->
    regex = new RegExp "^#{role}$", "i"
    return s for s in @servers when s.role?.match regex

stageSchema.methods.getModule = (name) ->
    regex = new RegExp "^#{name}$", "i"
    return m for m in @modules when m.name?.match regex

# allow names to be aliased
stageSchema.methods.getNameRegexString = ->
    names = [regexEscape(@name)]
    switch @name.toLowerCase()
        when 'production'
            names.push 'live'
            names.push '(pre-?)?prod(uction)?'
        when 'qa'
            names.push 'q[\.\-]?a\.?'
        when 'uat'
            names.push 'u[\.\-]?a[\.\-]?t\.?'

    return "(#{names.join('|')})(?: (?:website|site|stage))?"

stageSchema.virtual('url', _jiri_aliasTarget: 'urls')
    .get -> @urls
    .set (urls) ->
        @urls = urls
        @markModified 'urls'

stageSchema.virtual('server', _jiri_aliasTarget: 'servers')
    .get -> @servers[0]

stageSchema.virtual('cmsVersion')
    .get -> @getModule('cms')?.version
stageSchema.virtual('clientVersion')
    .get -> @getModule('client')?.version
stageSchema.virtual('customerVersion')
    .get -> @getModule('client')?.version
stageSchema.virtual('xfpVersion')
    .get -> @getModule('xfp')?.version

stageSchema.virtual('versions', _jiri_aliasTarget: 'modules')
    .get -> @modules

module.exports = stageSchema
