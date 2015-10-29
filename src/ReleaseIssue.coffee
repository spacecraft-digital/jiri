config = require '../config'
Issue = require './Issue'
stringUtils = require './utils/string'

class ReleaseIssue extends Issue

    synonyms:
        latest: ['latest']
        previous: ['last', 'previous']
        next: ['next', 'current', 'active', 'in progress']

    constructor: (issueData) ->
        super issueData

        version = issueData.fields[config.jira_field_release_version]?[0]
        unless version
            m = issueData.fields.summary.match /\s(\d+\.\d+)/
            version = m[1] if m

        # version will be a x.y or NULL
        @version = stringUtils.normaliseVersion version, 2

        # ignore four point versions (likely to be a core product, e.g. 1.12.1.16)
        @version = null if @version and @version.split('.').length > 3

        # three point version, for use in semver comparisons
        @semver = if @version then stringUtils.normaliseVersion @version, 3  else '0.0.0'

module.exports = ReleaseIssue
