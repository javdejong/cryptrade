https = require 'https'
inspect = require('util').inspect

module.exports =
  inspect: (obj)->
    result = inspect obj,
      colors:true
    result.replace '\n',' '
  downloadURL: (url,cb)->
    req = https.request url, (res)->
      res.on 'data', (data) ->
        cb(null,data)
    req.end()
    req.on 'error', (e)->
      cb(e)

  printDate: (date) ->
    padStr = (x) ->
      if (x < 10)
        x = "0" + x
      else
        x = "" + x
      x

    dateStr = padStr(date.getFullYear()) + "-" +
              padStr(1 + date.getMonth()) + "-" +
              padStr(date.getDate()) + " " +
              padStr(date.getHours()) + ":" +
              padStr(date.getMinutes())


  # Deep copy
  # Taken from http://coffeescriptcookbook.com/chapters/classes_and_objects/cloning
  deepclone: (obj) ->
    clone = (obj) ->
      # The "isnt function" part is new, to also clone functions/classes. Might results in other weird stuff
      # being cloned as well?
      if not obj? or (typeof obj isnt 'object' and typeof obj isnt 'function')
        return obj

      if obj instanceof Date
        return new Date(obj.getTime())

      if obj instanceof RegExp
        flags = ''
        flags += 'g' if obj.global?
        flags += 'i' if obj.ignoreCase?
        flags += 'm' if obj.multiline?
        flags += 'y' if obj.sticky?
        return new RegExp(obj.source, flags)

      newInstance = new obj.constructor()

      for key of obj
        newInstance[key] = clone obj[key]

      return newInstance

    return clone(obj)
