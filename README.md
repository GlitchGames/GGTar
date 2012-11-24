GGTar
============

This is a GGified version of the Tar module for the LuaRocks project provided 
here - https://github.com/keplerproject/luarocks/blob/master/src/luarocks/tools/tar.lua

Basic Usage
-------------------------

##### Require The Code
```lua
local GGTar = require( "GGTar" )
```

##### Create your GGTar object
```lua
local tar = GGTar:new()
```

##### Untar an archive in the temp directory into the documents directory and call a function when done.
```lua
local onComplete = function()
	print( "All done!" )
end
tar:untar( "level1.tar", system.DocumentsDirectory, system.TemporaryDirectory, onComplete )
```

##### Destroy this GGTar object
```lua
tar:destroy()
```

Update History
-------------------------

##### 0.1
Initial release