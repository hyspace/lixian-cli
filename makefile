all:
	./node_modules/.bin/coffee -b -c ./bin/lixian-cli.coffee ./task.coffee
	sed -i.bak 's/^\/\/.*/#!\/usr\/bin\/env node/' ./bin/lixian-cli.js
	rm ./bin/lixian-cli.js.bak
	chmod +x ./bin/lixian-cli.js
