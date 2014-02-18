#!/usr/bin/env node
var Q, cli, configJsonPath, configPath, download, findAndDownload, fs, getList, homePath, isInt, path, progress, request, saveList, showList, task;

Q = require('q');

fs = require("fs");

cli = require("cli").enable("version", "help", "status");

path = require("path");

task = require(path.resolve(__dirname, '../index'));

request = require('request');

progress = require('request-progress');

homePath = process.env['HOME'];

configPath = path.join(homePath, ".lixian-cli");

configJsonPath = path.join(configPath, "config.json");

String.prototype.cut = function(length) {
  var i, sub, _i, _ref;
  for (i = _i = _ref = this.length; _ref <= 1 ? _i <= 1 : _i >= 1; i = _ref <= 1 ? ++_i : --_i) {
    sub = this.substring(0, i);
    if (sub.replace(/[^\x00-\xff]/g, "**").length <= length) {
      return sub;
    }
  }
};

isInt = function(n) {
  return !isNaN(parseInt(n, 10)) && isFinite(n);
};

download = function(url, dest, options) {
  var lastRecieved, q;
  q = Q.defer();
  lastRecieved = 0;
  cli.ok("Start download " + options.name);
  progress(request({
    url: url,
    headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Trident/6.0)',
      'Cookie': options.cookies,
      'Referer': options.refer
    },
    proxy: 'http://127.0.0.1:8888'
  }), {
    throttle: 1000
  }).on('progress', function(state) {
    var speed;
    speed = state.received - lastRecieved;
    lastRecieved = state.received;
    return cli.spinner("Downloading... " + state.received + "\t/" + state.total + "\t" + state.percent + "%\t" + (Math.round(speed / 1024)) + "KB/s", true);
  }).on('error', function(err) {
    return cli.debug(err.toString());
  }).pipe(fs.createWriteStream(dest)).on('error', function(err) {
    return cli.debug(err.toString());
  }).on('close', function(err) {
    if (!err) {
      return q.resolve();
    } else {
      return q.reject({
        error: err
      });
    }
  });
  return q.promise;
};

getList = function() {
  var config, e;
  if (!fs.existsSync(configJsonPath)) {
    cli.fatal("Config file do not Exist.\n Login or fetch first and try again.");
  }
  try {
    config = require(configJsonPath);
    if (!((config.referer != null) && (config.cookies != null) && (config.tasks != null))) {
      throw new Error('Config file format error.');
    }
  } catch (_error) {
    e = _error;
    cli.debug(e.toString());
    cli.fatal("Load config file failed.");
  }
  return config;
};

findAndDownload = function(index1, index2, dest) {
  var config, file, files, options;
  if (index1 == null) {
    index1 = 0;
  }
  if (index2 == null) {
    index2 = null;
  }
  config = getList();
  options = {
    referer: config.referer,
    cookies: config.cookies
  };
  files = config.tasks;
  if (index1 < files.length) {
    file = files[index1];
    if (file.type === 'file') {
      options.name = file.name;
      return download(file.url, path.resolve(dest, file.name), options);
    } else if (file.type === 'folder') {
      if (index2 == null) {
        index2 = 0;
        cli.info('Subindex not provided, use `0`.');
      }
      if (index2 < file.files.length) {
        file = file.files[index2];
        options.name = file.name;
        return download(file.url, path.resolve(dest, file.name), options);
      } else {
        return false;
      }
    }
  } else {
    return false;
  }
};

showList = function(files, index) {
  var file, showOne, _i, _len, _results;
  showOne = function(file) {
    var sub_file, sub_index, _i, _len, _ref, _results;
    if (file.type === 'file') {
      return console.log(("" + index + "\t" + file.name).cut(process.stdout.columns - 6));
    } else {
      _ref = file.files;
      _results = [];
      for (sub_index = _i = 0, _len = _ref.length; _i < _len; sub_index = ++_i) {
        sub_file = _ref[sub_index];
        _results.push(console.log(("" + index + "-" + sub_index + "\t" + sub_file.name).cut(process.stdout.columns - 8)));
      }
      return _results;
    }
  };
  if (index == null) {
    _results = [];
    for (index = _i = 0, _len = files.length; _i < _len; index = ++_i) {
      file = files[index];
      _results.push(showOne(file));
    }
    return _results;
  } else {
    file = files[index];
    return showOne(file);
  }
};

saveList = function(json) {
  var e, fd;
  try {
    fd = fs.openSync(configJsonPath, 'w');
    fs.writeSync(fd, JSON.stringify(json));
    return fs.closeSync(fd);
  } catch (_error) {
    e = _error;
    cli.debug(e.toString());
    return cli.fatal("Write config file failed.");
  }
};

cli.parse({
  page: ["P", "Page of lixian tasks", "number", 1],
  username: ["u", "Username", "string"],
  password: ["p", "Password", "string"],
  tasknum: ["n", "Tasks per page in [30, 50, 80, 100]", "number", 30]
}, ["fetch", "show", "download", "add", "login"]);

cli.main(function(args, options) {
  var dest, index1, index2, indexArray, json, q, url;
  switch (options.tasknum) {
    case 50:
    case 80:
    case 100:
      break;
    default:
      options.tasknum = 30;
  }
  switch (cli.command) {
    case "login":
      if (!((options.username != null) && (options.password != null))) {
        cli.fatal('Login failed. Username and password should be provided.');
      }
      task.login(options.username, options.password, options).then(function(json) {
        saveList(json);
        cli.ok('Login succeed.');
        return process.exit(0);
      }, function(reason) {
        cli.debug('error: ' + reason.error.toString());
        cli.debug('stdout:' + reason.stderr);
        cli.debug('stderr:' + r(eason.stderr));
        return cli.fatal('Login failed. Add --debug to options to see what happend.');
      });
      break;
    case "fetch":
      task.fetch(options).then(function(json) {
        saveList(json);
        showList(json.tasks);
        return process.exit(0);
      }, function(reason) {
        cli.debug('error: ' + reason.error.toString());
        cli.debug('stdout:' + reason.stderr);
        cli.debug('stderr:' + r(eason.stderr));
        return cli.fatal('Fetch failed. Add --debug to options to see what happend.');
      });
      break;
    case "show":
      json = getList();
      showList(json.tasks);
      process.exit(0);
      break;
    case "download":
      if (args.length > 2) {
        cli.fatal("Command should be `lixian-cli download [index] [path]`");
      } else if (args.length === 1 || args.length === 2) {
        if (args.length === 2) {
          dest = path.resolve(__dirname, args[1]);
          if (!fs.existsSync(path.resolve(__dirname, dest))) {
            cli.fatal("Destination path `" + dest + "` do not exist.");
          }
        } else {
          dest = './';
        }
        indexArray = args[0].split('-');
        if (indexArray.length === 1) {
          index1 = parseInt(indexArray[0], 10);
          if (!isInt(index1)) {
            cli.fatal('Index should be in format like 1-4 or 0-10.');
          }
        } else {
          index1 = parseInt(indexArray[0], 10);
          index2 = parseInt(indexArray[1], 10);
          if (!(isInt(index1) && isInt(index2))) {
            cli.fatal('Index should be in format like 1-4 or 0-10.');
          }
        }
      } else {
        index1 = 0;
      }
      if (!(q = findAndDownload(index1, index2, dest))) {
        cli.fatal("Can not find file to download by provided index.");
      } else {
        q.then(function() {
          cli.ok("Download Complete.");
          return process.exit(0);
        }, function(reason) {
          return cli.fatal("Download Failed. " + (reason.error.toString()));
        });
      }
      break;
    case "add":
      if (args.length > 0) {
        url = args[0];
        task.add(url, options).then(function(json) {
          saveList(json);
          showList(json.tasks, 0);
          return process.exit(0);
        }, function(reason) {
          cli.debug('error: ' + reason.error.toString());
          cli.debug('stdout:' + reason.stderr);
          cli.debug('stderr:' + r(eason.stderr));
          return cli.fatal('Add failed. Add --debug to options to see what happend.');
        });
      } else {
        cli.fatal("File to add not found in args.  See lixian-cli --help for help");
      }
  }
});
