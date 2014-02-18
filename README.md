# lixian-cli 迅雷离线命令行工具

[English Version](README_EN.md)

一个基于casperjs和phantomjs的nodejs迅雷离线任务模块，包含一个命令行工具

功能:

* 添加任务
* 下载任务（命令行）
* 获得离线下载任务列表

## 安装

使用 `npm` 安装:

```shell
npm install -g lixian-cli
```

由于 phantomjs 依赖 FreeType, Fontconfig, linux用户需要安装它们。

```shell
sudo apt-get install libfreetype6 fontconfig
```

## 命令行工具说明

```shell
lixian-cli [OPTIONS] <command> [ARGS]
```

### 使用示例

```shell
$ lixian-cli login -u un -p pw

$ lixian-cli show

$ lixian-cli add 'http://example.com/favicon.ico'

$ lixian-cli download 0 ~/Downloads/
```

### 可选命令:

```shell
add, download, fetch, login, show
```

#### lixian-cli login -u USERNAME -p PASSWORD

登录，并获取任务列表。（任务列表不输出）

#### lixian-cli fetch \[-u USERNAME -p PASSWORD\]

更新离线下载任务列表，保存到本地缓存，并输出到命令行。

_需要先登录 或者在命令中包含用户名和密码参数以登录_

#### lixian-cli show

显示离线下载任务列表。这个命令不会连接服务器，只显示本地缓存。

#### lixian-cli download \[index\] \[destination path\]

下载指定序号对应的文件。序号的格式应该和 `show` 或 `fetch` 命令中输出的一致。

序号可能包含2部分，用`-`分开
`index` contains 2 part.

  对于单个文件的任务，序号应该为一个数字
  对于多个文件的任务，序号应该类似 `0-1`，用 `-` 分开


`path` 不应包含文件名，`lixian-cli`使用任务内文件的文件名作为下载后文件的文件名

_需要先登录 如果距离上次成功登录或更新时间较长，可能会下载失败，需要重新登录。_

#### lixian-cli add [url] \[-u USERNAME -p PASSWORD\]

添加新任务。支持`magnet:`, `ed2k://`, `http(s)://` url, or `thunder://`，不支持上传种子文件（推荐使用磁力链接代替）

_需要先登录 或者在命令中包含用户名和密码参数以登录_

### 选项:

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

## 工作原理

工具使用 [casperjs](casperjs.org) 命令行浏览器，模拟用户实际操作。

[casperjs](casperjs.org)对内存的占用较大，不适合嵌入式设备使用（树莓派等硬件资源强大的除外）

## 模块 api

### 加载模块:

```js
lixianTask = require('lixian-cli')
```

### 方法

#### fetch(options)

返回 promise 对象

用法示例:

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
  // 得到json文件

  // json文件内容
  json: {
    referer:'url',      //迅雷任务页地址，用于http header
    cookies:'string',   //cookie字符串，用于http header
    tasks: [
      {
        type:'file',    //单一文件
        url: 'url'      //下载地址
        name:'string'   //文件名
      },
      {
        type:'folder',  //文件夹可能包含多个文件
        files:[
          {
            url: 'url'   //下载地址
            name:'string'//文件名
          }
        ]
      }
    ]
  }
},function(err){
  // 错误处理

  //错误对象内容
  err: {
    error:  'object' //命令行返回的异常对象
    stderr: 'string' //casperjs的错误输出
    stdout: 'string' //casperjs的输出
  }
})
```
#### add(url, options)

add(url, options)

_和在fetch的options中包含url参数的效果一致_

#### login(username, password, options)

login(username, password, options)

_和在fetch的options中包含用户名和密码参数的效果一致_