request = require 'request-promise'
config = require '../config'

module.exports = (word) ->
    request
        url: "http://api.giphy.com/v1/gifs/translate?s=#{word}&api_key=#{config.giphy_api_key}&rating=pg"
        json: true
    .then (response) ->
        response.data.images.fixed_height.url if response?.meta?.status is 200
