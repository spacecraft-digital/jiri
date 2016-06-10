config = require './config'
Git = require 'nodegit'
fs = require 'fs'
thenify = require 'thenify'
semver = require 'semver'
loops = require 'node-while-loop'

class Repo
    constructor: (@name) ->
        @path = "#{config.git_repos_folder}/#{@name}"
        @url = "https://gitlab.hq.jadu.net/implementations/#{@name}.git"

    getCloneExists: =>
        thenify(fs.stat) @path
        .catch (err) ->
            if err.code is 'ENOENT'
                return null
            else
                throw err
        .then (stats) ->
            Promise.resolve stats?.isDirectory()

    getRepo: =>
        return Promise.resolve @repo if @repo
        @getCloneExists().then (exists) =>
            if exists
                Git.Repository.open @path
            else
                console.log 'cloning'
                Git.Clone @url, @path, bare: 1
        .then (repo) =>
            @repo = repo

    getTags: =>
        Promise.resolve @tags if @tags

        @getRepo().then (repo) -> repo.getReferences(Git.Reference.TYPE.OID)
        .then =>
            @tags = (reference for reference in arguments[0] when reference.isTag())
            @tags.sort (a, b) ->
                aName = a.shorthand()
                bName = b.shorthand()
                # sort so that non-semver versions are put first
                if semver.valid(aName) and semver.valid(bName) then semver.compare(aName, bName) else -1
            @tags

    getLatestTag: =>
        @getTags().then (tags) =>
            tags[tags.length-1]

    getLatestVersion: =>
        @getLatestTag().then (latestTag) ->
            Promise.Resolve latestTag.shorthand().trim()

        # latestReleaseNumber = "#{semver.major @latestVersion}.#{semver.minor @latestVersion}.0"
        # latestReleaseNumberIndex = tags.findIndex (tag) -> tag.shorthand() is latestReleaseNumber
        # if latestReleaseNumberIndex is -1
        #     throw new Error "Tag #{latestReleaseNumber} not found in repo"
        # previousReleaseLastTag = tags[latestReleaseNumberIndex-1]

    getFeaturesSince: (branchName, sinceCommit) =>
        refs = []
        eachCommit = (commit) ->
            # break once we hit our reference commit
            return refs if commit.id().equal sinceCommit

            # record merge commits with a summary that contains a JIRI ref
            if commit.parents().length > 1 and m = commit.summary().match /\b(?:SPC|SUP)-\d{3,6}\b/i
                refs.push m[0].toUpperCase()

            # move up the chain
            commit.getParents(1).then (parents) ->
                # we've hit the end of the branch!
                throw new Error "Commit #{sinceCommit} not found in #{branchName} branch" unless parents.length
                # look at the next commit in the ancestor chain (only following the first parent)
                eachCommit parents[0]

        @repo.getBranchCommit branchName
        .then eachCommit

    # find a commit in the given branch/tag that matches the test function
    findCommit: (refName, testFunction) =>
        @getRepo().then (repo) =>
            repo.getReferenceCommit refName
        .then (commit) ->
            new Promise (resolve, reject) =>
                history = commit.history()
                history.on 'commit', (commit) ->
                    if testFunction commit
                        history.removeAllListeners()
                        return resolve commit
                history.on 'end', (commits) -> resolve null
                history.on 'error', (error) -> reject error
                history.start()

    # returns true if the `commit` is the target of one of the `tags`
    isCommitTagged: (tags, commit) ->
        return true for t in tags when t.target().equal commit.id()
        return false



repo = new Repo process.argv[2]

repo.getTags()
.then (tags) ->
    Promise.all [
        tags[tags.length-1]
        repo.findCommit 'dev', repo.isCommitTagged.bind(repo, tags)
    ]
.then ([latestTag, firstTaggedCommit]) ->
    # Latest tag is in dev branch
    if latestTag.target().equal firstTaggedCommit.id()
        repo.getFeaturesSince('dev', firstTaggedCommit)
    else
        console.log 'need to merge release branch'
.then (refs) ->
    console.log "Features not yet released", refs
