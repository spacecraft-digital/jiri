# initialising inflect and adding custom inflections to be used globally
inflect = require('i')()
config = require '../../config'

if config.inflections?.singular
    for plural, singular of config.inflections.singular
        inflect.inflections.singular plural, singular

module.exports = inflect
