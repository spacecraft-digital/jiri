mongoose = require 'mongoose'

repositorySchema = mongoose.Schema
    id: Number
    name: String
    # path in Gitlab
    codename: String
    description: String

    # default_branch in Gitlab
    defaultBranch: String

    # ssh_url_to_repo in Gitlab
    sshUrl: String
    # http_url_to_repo in Gitlab
    httpUrl: String
    # web_url in Gitlab
    webUrl: String

    # avatar_url in Gitlab
    avatarUrl: String

    # merge_requests_enabled in Gitlab
    mergeRequestsEnabled: Boolean
    # wiki_enabled in Gitlab
    wikiEnabled: Boolean

    # created_at in Gitlab
    createdDate: Date
    # last_activity_at in Gitlab
    lastActivityDate: Date

    namespace:
        id: Number
        name: String
        # path in Gitlab
        codename: String

(require './_Base').applyTo repositorySchema

repositorySchema.methods.getName = -> @webUrl

module.exports = repositorySchema
