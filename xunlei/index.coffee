# input args
USERNAME = null
PASSWORD = null
PAGE = null
TASKNUM = null
URL = null
DELETE = null


# control flow args
LOGGED_IN = false
LIST = null
TIMEOUT = TIMEOUT

fs = require 'fs'

casper = require('casper').create
  pageSettings:
    webSecurityEnabled: false
    loadImages: false
    loadPlugins: false
    userAgent: 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Trident/6.0)'
  verbose: true

# output
casper.STDDEBUG = ''
casper.STDOUT = ''
casper.debug = (str)->
  @STDDEBUG += str + '\n'
casper.output = (str)->
  @STDOUT += str
casper.dieWithMessage = (str)->
  @echo @STDDEBUG
  @die str
casper.exitWithMessage = ->
  @echo @STDOUT
  @exit()

USERNAME = casper.cli.options['username']
PASSWORD = casper.cli.options['password']
PAGE = casper.cli.options['page'] || 1
TASKNUM = casper.cli.options['tasknum'] || 30
URL = casper.cli.options['url']
DELETE = casper.cli.options['delete']

casper.start "http://lixian.xunlei.com", ->
  url = @getCurrentUrl()
  @debug '\nOpened ' + url

casper.then ->
  @waitForUrl /dynamic\.cloud\.vip\.xunlei.com\/user_task/ig, ->
    LOGGED_IN = true
    @debug 'Already logged in.'

  , ->
    LOGGED_IN = false
    @debug 'Need logging in.'

  , TIMEOUT

# skip login and check login if logged in
casper.thenBypassIf ->
  LOGGED_IN
, 2

# log in
casper.then ->
  @debug 'Trying to login...'

  unless USERNAME and PASSWORD
    @dieWithMessage 'No username or password is being provided.\nAdd username and password and then try again.'

  @waitForSelector 'form', ->
    @fillSelectors "form",
      'input[name="u"]' : USERNAME
      'input[type="password"]' : PASSWORD
      'input[name="login_enable"]' : true
    , false

    @click "#button_submit4reg"

  ,->
    @debug @getCurrentUrl()
    @dieWithMessage 'Login failed.\nGo to https://github.com/hyspace/lixian-cli to see if xunlei api have changed.'


# check log in
casper.then ->
  @waitForUrl /dynamic\.cloud\.vip\.xunlei.com\/user_task/ig, ->
    @debug 'Logged in success.'

  , ->
    @dieWithMessage 'Login failed.\nGo to https://github.com/hyspace/lixian-cli to see if xunlei api have changed.'

  , TIMEOUT

# skip add task if no url provided
casper.thenBypassIf ->
  !URL
, 1

# add task
casper.then ->
  @click 'a.sit_new'

  @waitUntilVisible '#task_url', ->
    @evaluate (URL)->
      $('#task_url').val(URL);
    , URL

    @waitForSelector '#down_but:not([disabled])', ->
      @click '#down_but'

      @waitForResource 'showtask_unfresh', ->
        @debug 'Add new task succeed.'

      , ->
        @dieWithMessage 'Add new task request timeout.'
      , TIMEOUT

    , ->
      @dieWithMessage 'Get new task info callback timeout.'
    , TIMEOUT

  , ->
    @dieWithMessage 'Add new task popup timeout.'
  , TIMEOUT


# skip delete task if no delete provided
casper.thenBypassIf ->
  !DELETE
, 1
casper.then ->

  @evaluate (DELETE) ->
    # main logic to get tasks
    $.post INTERFACE_URL + "/task_delete?callback=&type=0",
      taskids: DELETE
      databases: 0
      interfrom: G_PAGE
    , (process) ->
      window.__task_deleted__ = true
      return
    return
  , DELETE
  @waitFor ->
    LIST = @evaluate ->
      window.__task_deleted__
    LIST


# get list
casper.then ->
  pageContext =
    page: PAGE
    tasknum: TASKNUM

  @evaluate (pageContext) ->
    # main logic to get tasks
    $.getJSON INTERFACE_URL + "/showtask_unfresh?callback=?",
      type_id: 4
      page: pageContext.page
      tasknum: pageContext.tasknum
      t: (new Date()).toString()
      p: pageContext.page,
      interfrom: G_PAGE

    , (process) ->
      if process.info && process.info.tasks
        tasks = process.info.tasks
        window.__task_data__ = list = []
        for task in tasks
          if task.tasktype == 1
            list.push
              type:'file'
              name:task.taskname
              url:task.lixian_url
              id: task.id

          else if task.tasktype == 0
            (->
              folder =
                type:'folder'
                name:task.taskname
                files:[]
                unready:true
                id: task.id

              list.push folder

              $.get INTERFACE_URL+"/fill_bt_list",
                callback:'bt_task_down_resp'
                tid:task.id
                infoid:task.cid
                g_net:G_section
                p:page
                uid:G_USERID
                interfrom:G_PAGE

              , (data)->
                if jsonStr = data.match(/bt_task_down_resp\((.*)\)/i)[1]
                  result = JSON.parse(jsonStr).Result
                  for item in result
                    folder.files.push
                      name:item.title
                      url:item.downurl
                  delete folder.unready

              ,'text'
            )()
      return
    return
  , pageContext

  @waitFor ->
    LIST = @evaluate ->
      if window.__task_data__ == null then return false
      for task in window.__task_data__
        if task.type == 'file' then continue
        else
          if task.files.length == 0 then return false
          for file in task.files
            if file.unready then return false

      window.__task_data__
    LIST

  , ->
    output = {}

    cookiesStr = ''
    for cookie in @page.cookies
      cookiesStr += "#{cookie.name}=#{cookie.value}; "
    cookiesStr = cookiesStr.substring 0, cookiesStr.length - 2

    output.cookies = cookiesStr
    output.referer = @getCurrentUrl()
    output.tasks = LIST

    @output JSON.stringify(output)
    @exitWithMessage()
  , ->
    @dieWithMessage 'Get list failed.'

  , TIMEOUT * 2

casper.run()
