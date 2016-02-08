middlewareUtils = require "#{process.env.FOF_SRC}/server/middleware/utilities.js"

module.exports = (server) ->

  # User custom middleware utilities
  server.use middlewareUtils.setHeaders

  return