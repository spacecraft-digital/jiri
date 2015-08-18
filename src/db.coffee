
Datastore = require './../node_modules/nedb'

db = {}
db.clients = new Datastore
    filename: 'data/clients'
    autoload: true

db.clients.ensureIndex
    fieldName: 'alias'
    unique: true

module.exports = db
