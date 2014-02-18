#!/usr/bin/env coffee
Q = require('q')
fs = require("fs")
cli = require("cli").enable("version", "help", "status")
path = require("path")
task = require(path.resolve(__dirname,'../index'))
request = require('request')
progress = require('request-progress')

homePath = process.env['HOME']
configPath = path.join(homePath, ".lixian-cli")
configJsonPath = path.join(configPath, "config.json")

#helpers
String.prototype.cut = (length)->
  for i in [@length..1]
    sub = @substring(0, i)
    return sub if sub.replace(/[^\x00-\xff]/g, "**").length <= length

isInt = (n) ->
  !isNaN(parseInt(n, 10)) and isFinite(n)

download = (url, dest, options)->
  q = Q.defer()
  lastRecieved = 0
  cli.ok "Start download #{options.name}"
  progress(
    request(
      url:url
      headers:
        'User-Agent':'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Trident/6.0)'
        'Cookie':options.cookies
        'Referer':options.refer
      # proxy:'http://127.0.0.1:8888'
    )
  ,
    throttle: 1000
  )
  .on('progress', (state)->
    speed = state.received - lastRecieved
    lastRecieved = state.received
    cli.spinner "Downloading... #{state.received}\t/#{state.total}\t#{state.percent}%\t#{Math.round(speed/1024)}KB/s", true
  )
  .on('error', (err)->
    cli.debug err.toString()
  )
  .pipe(fs.createWriteStream(dest))
  .on('error', (err)->
    cli.debug err.toString()
  )
  .on('close', (err)->
    if !err
      q.resolve()
    else
      q.reject( error:err )
  )

  q.promise

getList = ()->
  unless fs.existsSync(configJsonPath)
    cli.fatal "Config file do not Exist.\n Login or fetch first and try again."
  try
    config = require(configJsonPath)
    unless config.referer? and config.cookies? and config.tasks?
      throw new Error('Config file format error.')
  catch e
    cli.debug e.toString()
    cli.fatal "Load config file failed."

  return config

findAndDownload = (index1 = 0, index2 = null, dest)->
  config = getList()
  options =
    referer:config.referer
    cookies:config.cookies
  files = config.tasks
  if index1 < files.length
    file = files[index1]
    if file.type == 'file'
      options.name = file.name
      return download file.url, path.resolve(dest, file.name), options
    else if file.type == 'folder'
      unless index2?
        index2 = 0
        cli.info 'Subindex not provided, use `0`.'
      if index2 < file.files.length
        file = file.files[index2]
        options.name = file.name
        return download file.url, path.resolve(dest, file.name), options
      else
        return false
  else
    return false


showList = (files, index)->
  showOne = (file)->
    if file.type == 'file'
      console.log "#{index}\t#{file.name}".cut process.stdout.columns - 6
    else
      for sub_file, sub_index in file.files
        console.log "#{index}-#{sub_index}\t#{sub_file.name}".cut process.stdout.columns - 8

  unless index?
    for file, index in files
      showOne(file)
  else
    file = files[index]
    showOne(file)

saveList = (json)->
  try
    fd = fs.openSync(configJsonPath, 'w')
    fs.writeSync(fd, JSON.stringify json)
    fs.closeSync(fd)
  catch e
    cli.debug e.toString()
    cli.fatal "Write config file failed."


# cli
cli.parse(
# options
  page:         ["P", "Page of lixian tasks",                "number", 1 ]
  username:     ["u", "Username",                            "string"    ]
  password:     ["p", "Password",                            "string"    ]
  tasknum:      ["n", "Tasks per page in [30, 50, 80, 100]", "number", 30]
,
# commands
["fetch", "show", "download", "add", "login"]
)
cli.main (args, options) ->
  switch options.tasknum
    when 50, 80, 100
    else
      options.tasknum = 30
  # tasks
  switch cli.command
    when "login"
      unless options.username? and options.password?
        cli.fatal 'Login failed. Username and password should be provided.'
      task.login(options.username, options.password, options).then (json)->
        saveList(json)
        cli.ok 'Login succeed.'
        process.exit(0)
      , (reason)->
        cli.debug 'error: ' + reason.error.toString()
        cli.debug 'stdout:' + reason.stderr
        cli.debug 'stderr:' +r eason.stderr
        cli.fatal 'Login failed. Add --debug to options to see what happend.'

    when "fetch"
      task.fetch(options).then (json)->
        saveList(json)
        showList(json.tasks)
        process.exit(0)
      , (reason)->
        cli.debug 'error: ' + reason.error.toString()
        cli.debug 'stdout:' + reason.stderr
        cli.debug 'stderr:' +r eason.stderr
        cli.fatal 'Fetch failed. Add --debug to options to see what happend.'

    when "show"
      json = getList()
      showList(json.tasks)
      process.exit(0)

    when "download"
      if args.length > 2
        cli.fatal "Command should be `lixian-cli download [index] [path]`"
      else if args.length == 1 or args.length == 2
        if args.length == 2
          dest = path.resolve(__dirname, args[1])
          if !fs.existsSync path.resolve(__dirname, dest)
            cli.fatal "Destination path `#{dest}` do not exist."
        else
          dest = './'

        indexArray = args[0].split '-'
        if indexArray.length == 1
          index1 = parseInt(indexArray[0], 10)
          unless isInt(index1)
            cli.fatal 'Index should be in format like 1-4 or 0-10.'
        else
          index1 = parseInt(indexArray[0], 10)
          index2 = parseInt(indexArray[1], 10)
          unless isInt(index1) and isInt(index2)
            cli.fatal 'Index should be in format like 1-4 or 0-10.'
      else # args.length == 0
        index1 = 0

      unless q = findAndDownload(index1, index2, dest)
        cli.fatal "Can not find file to download by provided index."
      else
        q.then ->
          cli.ok "Download Complete."
          process.exit(0)
        , (reason)->
          cli.fatal "Download Failed. #{reason.error.toString()}"

    when "add"
      if args.length > 0
        url = args[0]
        task.add(url, options).then (json)->
          saveList(json)
          showList(json.tasks, 0)
          process.exit(0)
        , (reason)->
          cli.debug 'error: ' + reason.error.toString()
          cli.debug 'stdout:' + reason.stderr
          cli.debug 'stderr:' +r eason.stderr
          cli.fatal 'Add failed. Add --debug to options to see what happend.'

      else
        cli.fatal "File to add not found in args.  See lixian-cli --help for help"
  return