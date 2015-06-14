
Datastore = require './../node_modules/nedb'

db = {}
db.clients = new Datastore
    filename: 'data/clients'
    autoload: true

db.clients.ensureIndex
    fieldName: 'codename'
    unique: true

module.exports = db
