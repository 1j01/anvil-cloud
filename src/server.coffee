
PORT = process.env.OPENSHIFT_NODEJS_PORT ? process.env.PORT ? 8080
IP = process.env.OPENSHIFT_NODEJS_IP ? process.env.IP ? '127.0.0.1'

express = require 'express'
app = express()
server = app.listen(PORT, IP)
console.log "Server listening on http://#{IP}:#{PORT}/"

app.use express.static(__dirname)

Firebase = require 'firebase'
rootRef = new Firebase "https://incus.firebaseio.com/local/"
scriptsRef = rootRef.child 'scripts'

#Firepad = require 'firepad'




# We'll use temporary files for scripts
fs = require 'fs'
temp = require 'temp'

# Keep track of temporary files and remove them on exit
temp.track()

{spawn, exec} = require 'child_process'






class Script
	constructor: (@ref)->
		
		for prop in ['name', 'lang', 'code', 'run', 'running', 'error']
			do (prop)=>
				@[prop] = null
				@[prop + 'Ref'] = @ref.child prop
				@["#{prop}Ref"].on 'value', (snap)=>
					@[prop] = snap.val()
		
		@nameRef.on 'value', (snap)=>
			#console.log "Script `#{snap.val()}`"
		@runRef.on 'value', (snap)=>
			weShouldBeRunning = snap.val()
			
			errorHandler = (err)=>
				if err
					console.error err
					@errorRef.set err
					@runRef.set no # probably a bad idea
			
			if not @running and weShouldBeRunning
				@launch(errorHandler)
			else if @running and not weShouldBeRunning
				@terminate(errorHandler)
	
	launch: (callback)->
		@terminate()
		
		console.log "\n\nLaunching Script `#{@name}`"
		
		temp.open 'script', (err, {fd, path})=>
			if err
				return callback err
			else
				fs.write fd, @code
				fs.close fd, (err)=>
					if err
						return callback err
					#else
					#	callback null
					
					
					switch @lang
						when "javascript", "js"
							console.log "Spawing ChildProcess `node` for Script `#{@name}`"
							#executable = "node"
							@process = spawn "node", [path]
						when "coffeescript", "coffee", "coffee-script"
							console.log "Spawing ChildProcess `coffee` for Script `#{@name}`"
							executable = (require 'path').join __dirname, "../node_modules/.bin/coffee"
							if process.platform is "win32"
								executable += ".cmd"
							console.log executable
							#executable = "./node_modules/.bin/coffee"
							@process = spawn executable, [path]
						else
							return callback new Error "unknown lang `#{@lang}`"
					
					#@process = spawn executable, [path]
					# @process = exec "#{executable} #{path}"
					
					#console.log executable, path
					
					@runningRef.set yes
					
					@process.on 'error', (err)=>
						@runningRef.set no #...probably not.. running.. >:-] ?
						@runRef.set no # probably a bad idea
						console.log 'error spawning process (or something)', err
					
					@process.on 'exit', =>
						@runningRef.set no
						@runRef.set no # probably a bad idea
						console.log 'process exited'
					
					@process.stdout.on 'data', (data)=>
						console.log "Script `#{@name}` stdout: #{data}"

					@process.stderr.on 'data', (data)=>
						console.log "Script `#{@name}` stderr: #{data}"
						

		
	terminate: ->
		@process?.kill()

scriptsRef.on 'child_added', (snap)->
	new Script snap.ref()

