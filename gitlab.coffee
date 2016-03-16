return
process.stdout.write '\u001B[2J\u001B[0;0f'

config = require './config'

gitlab = (require 'gitlab')
  url:   config.gitlab_url
  token: config.gitlab_token

mongoose = require './database_init'
IsoSpreadsheet = require './src/IsoSpreadsheet'

Customer = mongoose.model 'Customer'
Project = mongoose.model 'Project'
Repository = mongoose.model 'Repository'

translateApiData = (data) ->
    id: data.id
    name: data.name
    codename: data.path
    description: data.description
    defaultBranch: data.default_branch
    sshUrl: data.ssh_url_to_repo
    httpUrl: data.http_url_to_repo
    webUrl: data.web_url
    avatarUrl: data.avatar_url
    mergeRequestsEnabled: data.merge_requests_enabled
    wikiEnabled: data.wiki_enabled
    createdDate: data.created_at
    lastActivityDate: data.last_activity_at
    namespace:
        id: data.namespace.id
        name: data.namespace.name
        codename: data.namespace.path

console.log "Loading repos…"
gitlab.groups.show 43,
    (group) ->
        console.log "Group loaded"
        for repo in group.projects

            console.log "Processing #{repo.name}"
            callbackForProject = (repo) ->
                (customers) ->

                    # if this repo if it is already assigned to a project
                    Customer.findOne "projects.repos.id": repo.id
                    .then (repoCustomer) ->
                        if repoCustomer
                            repo = repoCustomer.getRepo repo.id
                            console.log "#{repo.sshUrl} is already assigned to #{customers[0].name}"
                            return

                        targetProject = false
                        switch customers.length
                            when 0 then console.log "I don't know which customer #{repo.normalizedName} is for"
                            when 1
                                customer = customers[0]
                                if customer.projects.length is 1
                                    targetProject = customer.projects[0]
                                else
                                    for project in customer.projects
                                        if repo.normalizedName.match new RegExp("\\b#{project.name}\\b",'i')
                                            targetProject = project
                                            break
                                    unless targetProject
                                        targetProject = customer.getProject(customer.defaultProjectName)
                            else console.log "#{repo.name} could be for", customers.map((c)->c.name).join(', ')

                        if targetProject
                            console.log targetProject
                            targetProject.repos.push translateApiData repo
                            customer.save ->
                                console.log "#{targetProject.name} saved"

            repo.normalizedName = repo.name
                # convert dashes to spaces
                .replace(/[_\-]+/g, ' ')
                # remove 'intranet' run-in suffix
                .replace(/(\w)(intranet)/g, '$1 $2')
                # uncamelize
                .replace(/((?=.)[^A-Z])([A-Z])(?=[^A-Z])/g, '$1 $2')
                # remove meaningless words
                .replace(/(112|\bpre\b|upgrade\b)/gi, '')
                # remove 'bc' or 'dc' run-in suffix
                .replace(/(\w{3,})[bd]c\b/gi, '$1')
                # trim leading/trailing spaces
                .replace(/(^\s+|\s+$)/g, '')
                # compact multiple spaces
                .replace(/ {2,}/g, ' ')

            Customer.findByName repo.normalizedName
            .then callbackForProject(repo)
