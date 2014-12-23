
E = (e)->
	parts = e.split '.'
	tagName = parts[0]
	$e = document.createElement tagName
	$e.className = parts[1] if parts[1]
	$e

$id = (id)-> document.getElementById id

after = (ms, fn)-> setTimeout(fn, ms)
every = (ms, fn)-> setInterval(fn, ms)
print = console.log

$Script = (scriptRef, $container)->
	$script = E "div.script"
	$container.appendChild $script
	
	$header = E "div.script-header"
	$script.appendChild $header
	
	# Script Name
	$name = E "input.script-name"
	$header.appendChild $name
	
	nameRef = scriptRef.child 'name'
	nameRef.on 'value', (snap)=>
		name = snap.val()
		if name? and $name.value != name
			$name.value = name
	$name.onchange = $name.onkeypress = $name.onkeyup = =>
		nameRef.set($name.value)
	
	# The Editor
	$editorContainer = E "div.editor-container"
	$script.appendChild $editorContainer
	
	$editor = E "div" # we have to make and append this element just so it can be replaced! >:(
	$editorContainer.appendChild $editor
	editor = new Editor(scriptRef, $editor)
	#editor.on 'change', =>
	#	console.log editor
	#	(scriptRef.child 'code').set editor.getValue()
	
	# Controls
	$controls = E "div.script-controls"
	$script.appendChild $controls
	
	$Button = (label, onclick)=>
		$b = E "button"
		$b.innerText = label
		$controls.appendChild $b
		$b.onclick = onclick
		$b
	
	# $start = $Button "Start", =>
	# 	(scriptRef.child 'run').set yes
	# $stop = $Button "Stop", =>
	# 	(scriptRef.child 'run').set no
	
	
	# Run / Stop
	$run = E "button.run-stop"
	$controls.appendChild $run
	
	$runningIndicator = E "span"
	$run.appendChild $runningIndicator
	
	$runLabel = E "span"
	$run.appendChild $runLabel
	
	u = (run)=>
		$run.className = if run then "run-stop run click-to-stop" else ".run-stop stop click-to-run"
		 # ■◩◪-●◉: http://shapecatcher.com/unicode/block/Geometric_Shapes
		$runningIndicator.innerText = if run then "◼ " else "▶ "
		$runLabel.innerText = if run then "Stop" else "Run"
	
	$run.onclick = =>
		(scriptRef.child 'code').set editor.getValue()
		switch $runLabel.innerText
			when "Run" #, "Run..."
				# $runLabel.innerText = "Run..."
				(scriptRef.child 'run').set yes
			when "Stop" #, "Stop..."
				# $runLabel.innerText = "Stop..."
				(scriptRef.child 'run').set no
	
	$someOtherAction = $Button "Action"
	$someOtherAction = $Button "@*&#$^*%!!!!!!"
	
	(scriptRef.child 'run').on 'value', (snap)=>
		u snap.val()
	
	(scriptRef.child 'running').on 'value', (snap)=>
		$runningIndicator.className = if snap.val() then "running" else "not-running"
		
	
	# Delete Script button
	$delete = E "button.script-delete"
	$delete.innerText = "Delete Script"
	$header.appendChild $delete
	
	$delete.onclick = =>
		scriptRef.remove()
		scriptRef.on 'value', => scriptRef.remove() # stay dead
		$script.className += " disappearing"
		
		# hack to get height transition to work
		# we can't transition from auto to 0px, so compute auto (current height) into px
		$script.style.height = getComputedStyle?($script).height
		#console.log $editorContainer.style.height = getComputedStyle?($script).height
		# the transition only takes place with this delay
		after 1, =>
			$script.style.height = "0px"
			#$editorContainer.style.height = "0px"
		
		after 100000, =>
			editor.destroy()
			$script.parentElement.removeChild $script
	
	# Return
	$script
	
#editors = []
Editor = (scriptRef, $container)->
	
	# Create ACE
	editor = ace.edit $container
	#editors.push editor
	
	session = editor.getSession()
	
	
	# editor.setTheme "ace/theme/kr_theme" # quirky, purple selection... comments are hard to read especially when selected
	editor.setTheme "ace/theme/twilight" # 
	# editor.setTheme "ace/theme/clouds"
	# editor.setTheme "ace/theme/clouds_midnight" # ugly ugly
	(rootRef.child 'theme').on 'value', (snap)->
		theme = snap.val()
		if theme
			editor.setTheme theme
	
	session.setMode "ace/mode/javascript"
	
	editor.setOptions maxLines: 15, minLines: 5
	editor.setShowInvisibles no
	editor.setShowPrintMargin no
	session.setUseWrapMode yes
	session.setUseWorker no # disables syntax validation :(
	session.setUseSoftTabs no
	
	(scriptRef.child 'lang').on 'value', (snap)=>
		lang = snap.val()
		if lang?
			session.setMode "ace/mode/#{lang}"
	
	after 0, =>
		# Create Firepad
		firepad = Firepad.fromACE (scriptRef.child 'pad'), editor
	
	return editor
	

# Initialize Firebase
rootRef = new Firebase 'https://incus.firebaseio.com/local/'

# Scripts, scripts, scripts
scriptsRef = rootRef.child 'scripts'


# New script button
$newScript = $id 'new-script'
$newScript.onclick = =>
	newRef = scriptsRef.push {name: "New Script", code: "", lang: "coffee"}
	scriptsRef.once 'child_added', =>
		window.scrollBy(0, 5000)

# For each existing and new script
scriptsRef.on 'child_added', (snap)=>
	console.log 'v', snap.name()
	#$container = E "div.script-container"
	#($id 'scripts').appendChild $container
	$container = $id 'scripts'
	$s = new $Script(snap.ref(), $container)
	#$newScript.parentElement.insertBefore($s, $newScript)
	# execution order is magically reversed at this point
	# thanks to Ace editor (or maaaybe firepad, but idk)
	console.log '^', snap.name()
	#($id 'scripts').appendChild $s
	

# Themes dropdown
$themes = E "select.themes"
document.body.appendChild $themes

$light = E "optgroup"
$light.label = "Light"
$themes.appendChild $light

$dark = E "optgroup"
$dark.label = "Dark"
$themes.appendChild $dark

{themes, themesByName} = ace.require "ace/ext/themelist"
for theme in themes
	$theme = E "option"
	$theme.value = theme.theme
	$theme.innerText = theme.caption
	$optgroup = if theme.isDark then $dark else $light
	$optgroup.appendChild $theme

$themes.onchange = =>
	(rootRef.child 'theme').set $themes.value
	#for e in editors
	#	e.setTheme $themes.value

(rootRef.child 'theme').on 'value', (snap)=>
	#themeTheme = snap.val()
	#theme = theme for theme in themes when theme.theme is themeTheme
	theme = t for t in themes when t.theme is snap.val()
	
	$stylesheet = $id 'theme-stylesheet'
	
	f =
		if theme.caption.match /blue/i #/blue|solarized/i
			"blue"
		else
			if theme.isDark then "dark" else "light"
	
	href = "stylesheets/#{f}.css"
	
	$stylesheet.href = href #...
	console.log snap.val(), $stylesheet, href, theme
