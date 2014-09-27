path = require("path")
exec = require("child_process").exec
Q = require('q')

casperjsCmdPath = path.resolve(__dirname, "./node_modules/.bin/casperjs")
indexPath = path.resolve(__dirname, "./xunlei/index.coffee")
homePath = process.env['HOME']
configPath = path.join(homePath, ".lixian-cli")
cookieConfigPath = path.join(configPath, "cookies.txt")

casperTask = (options = {}) ->
  q = Q.defer()

  cmd = casperjsCmdPath +
        " --cookies-file=#{cookieConfigPath}"
  if options.page
    cmd +=" --page=#{options.page}"

  if options.tasknum
    cmd +=" --tasknum=#{options.tasknum}"

  if options.username and options.password
    cmd += " --username=#{options.username} --password='#{options.password}'"

  if options.url
    cmd += " --url='#{options.url}'"

  if options.delete
    cmd += " --delete='#{options.delete}'"

  cmd += " #{indexPath}"

  # console.log cmd

  exec cmd,
    maxBuffer: 1024 * 1024
    env:
      'PHANTOMJS_EXECUTABLE': path.resolve(__dirname, './node_modules/casperjs/node_modules/.bin/phantomjs')
  ,(error, stdout, stderr) ->
    unless error?
      try
        json = JSON.parse stdout
      catch e
        q.reject( error:'Task succeed, but got json with wrong format.')
      q.resolve(json)

    else
      q.reject(
        error:error
        stdout:stdout
        stderr:stderr
      )

    return

  q.promise

exports.add = (url, options = {})->
  if typeof url == 'string'
    options.url = url
    return casperTask(options)
  else
    return false

exports.delete = (id, options = {})->
  if typeof id == 'string'
    options.delete = id
    return casperTask(options)
  else
    return false


exports.fetch = (options)->
  return casperTask(options)

exports.login = (username, password, options = {})->
  if typeof username == 'string' and typeof password == 'string'
    options.username = username
    options.password = password
    return casperTask(options)
  else
    return false
