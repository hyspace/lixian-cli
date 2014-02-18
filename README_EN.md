# lixian-cli

A simple nodejs module including command line tool for xunlei-lixian service.

Supports:

* add tasks
* download files (cli tool)
* list tasks

## install

using `npm`:

```shell
npm install -g lixian-cli
```

Since phantomjs requires `FreeType`, `Fontconfig`, linux user should install them first:

```shell
sudo apt-get install libfreetype6 fontconfig
```

## cli tool usage

```shell
lixian-cli [OPTIONS] <command> [ARGS]
```

### example

```shell
$ lixian-cli login -u un -p pw

$ lixian-cli show

$ lixian-cli add 'http://example.com/favicon.ico'

$ lixian-cli download 0 ~/Downloads/
```

### Commands:
```shell
add, download, fetch, login, show
```

#### lixian-cli login -u USERNAME -p PASSWORD

Login, and then fetch tasks. (Does not output tasks in terminal)

#### lixian-cli fetch \[-u USERNAME -p PASSWORD\]

_Requires logging first. or with username and password as option to login._

Update and output tasks.

#### lixian-cli show

Show fetched tasks. This command do not update task list from server.

#### lixian-cli download \[index\] \[destination path\]

_Requires logged first. if you haven't logged in for a while, may be you should login again._

Download selected file. Format of index should be the same as that `show` or `fetch` command outputed.

`index` contains 2 part.

  Some task is single file, its index should be a number.

  Some task is a folder contains many files, so every file has a index like `0-1`

`path` shouldn't contains filename, `lixian-cli` will use filename in the task as output filename.

#### lixian-cli add [url] \[-u USERNAME -p PASSWORD\]

Add new task, protocols can be `magnet:`, `ed2k://`, `http(s)://` url, or `thunder://` (does not support upload `.torrent` files yet).

_Requires logging first. or with username and password as option to login._

###Options:

```shell
-P, --page [NUMBER]    Page of lixian tasks (Default is 1)
-u, --username STRING  Username
-p, --password STRING  Password
-n, --tasknum [NUMBER] Tasks per page in \[30, 50, 80, 100\] (Default is 30)
-k, --no-color         Omit color from output
    --debug            Show debug information
-v, --version          Display the current version
-h, --help             Display help and usage details
```

## How it works

This tool uses [casperjs](casperjs.org) to simulate how real user uses xunlei-lixian service.

## module api

### require module:

```js
lixianTask = require('lixian-cli')
```

### methods

#### fetch(options)

return a promise.

example:
```js
lixianTask = require('lixian-cli')
promise = lixianTask.fetch({
  page      : 1,
  tasknum   : 30,
  username  : 'un',
  password  : 'pw',
  url       : 'http://example.com/favicon.ico'
})
promise.then(function(json){
  // do sth

  // json content
  json: {
    referer:'url',         //Url of xunlei-lixian task page. Used in http header.
    cookies:'string',      //Cookie string for http header
    tasks: [
      {
        type:'file',       //Single file
        url: 'url'         //Url of file
        name:'string'      //Filename
      },
      {
        type:'folder',     //folder may contains multiple files
        files:[
          {
            url: 'url'     //Url of file
            name:'string'  //Filename
          }
        ]
      }
    ]
  }
},function(err){
  // handle the error

  // err content
  err: {
    error:  'object' //error object
    stderr: 'string' //error output of casperjs
    stdout: 'string' //standard output of casperjs
  }
})
```
#### add(url, options)

add(url, options)

_shortcut for fetch_

#### login(username, password, options)

login(username, password, options)

_shortcut for fetch_