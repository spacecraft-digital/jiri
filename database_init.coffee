mongoose = require 'mongoose'

mongoose = mongoose.connect 'mongodb://localhost/customers'

unless mongoose.modelNames().length
    mongoose.connection.on 'error', (error) -> console.error "Database error: #{error}"
    mongoose.connection.once 'open', (callback) -> console.log 'Database connected'

    customerSchema = require './schema/Customer'
    projectSchema = require './schema/Project'
    stageSchema = require './schema/Stage'
    serverSchema = require './schema/Server'
    moduleSchema = require './schema/Module'
    repositorySchema = require './schema/Repository'

    Customer = mongoose.model 'Customer', customerSchema
    Project = mongoose.model 'Project', projectSchema
    Stage = mongoose.model 'Stage', stageSchema
    Server = mongoose.model 'Server', serverSchema
    Module = mongoose.model 'Module', moduleSchema
    Repository = mongoose.model 'Repository', repositorySchema


module.exports = mongoose
