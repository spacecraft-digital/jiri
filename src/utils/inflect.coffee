# initialising inflex and adding custom inflections to be used globally
inflect = require('i')()

inflect.inflections.singular 'alias', 'alias'
inflect.inflections.singular 'aliases', 'alias'

module.exports = inflect
