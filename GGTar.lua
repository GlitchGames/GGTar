-- Project: GGTar
--
-- Date: November 24, 2012
--
-- Version: 0.1
--
-- File name: GGNews.lua
--
-- Author: Graham Ranson of Glitch Games - www.glitchgames.co.uk
--
-- Update History:
--
-- 0.1 - Initial release
--
-- Comments: 
--
--		This is a GGified version of the Tar module for the LuaRocks project provided 
--		here - https://github.com/keplerproject/luarocks/blob/master/src/luarocks/tools/tar.lua
--
-- Copyright (C) 2012 Graham Ranson, Glitch Games Ltd.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this 
-- software and associated documentation files (the "Software"), to deal in the Software 
-- without restriction, including without limitation the rights to use, copy, modify, merge, 
-- publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
-- to whom the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or 
-- substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
-- DEALINGS IN THE SOFTWARE.
--
----------------------------------------------------------------------------------------------------

local GGTar = {}
local GGTar_mt = { __index = GGTar }

local lfs = require( "lfs" )
local ceil = math.ceil
local tonumber = tonumber
local open = io.open

--- Initiates a new GGTar object.
-- @return The new GGTar object.
function GGTar:new()
    
    local self = {}
    
    setmetatable( self, GGTar_mt )
    
    self.blocksize = 512
    
    self.typeFlags = {}
    
    self.typeFlags[ "0" ] = "file"
    self.typeFlags[ "\0" ] = "file"
    self.typeFlags[ "1" ] = "link"
    self.typeFlags[ "2" ] = "symlink"
    self.typeFlags[ "3" ] = "character"
    self.typeFlags[ "4" ] = "block"
    self.typeFlags[ "5" ] = "directory"
    self.typeFlags[ "6" ] = "fifo"
    self.typeFlags[ "7" ] = "contiguous"
    self.typeFlags[ "x" ] = "next file"
    self.typeFlags[ "g" ] = "global extended header"
    self.typeFlags[ "L" ] = "long name"
    self.typeFlags[ "K" ] = "long link name"
   
    return self
    
end

function GGTar:getTypeFlag( flag )
	return self.typeFlags[ flag ]or "unknown"
end

function GGTar:octalToNumber( octal )
	
	local exp = 0
	local number = 0
	
	for i = #octal, 1, -1 do
	
		local digit = tonumber( octal:sub( i, i ) ) 
	
		if not digit then 
			break 
		end
	
		number = number + ( digit * 8 ^ exp )
		
		exp = exp + 1
	
	end
   
	return number
	
end

function GGTar:checksumHeader( block )
	
	local sum = 256
	
	for i = 1, 148 do
		sum = sum + block:byte( i )
	end
	
	for i = 157, 500 do
		sum = sum + block:byte( i )
	end
	
	return sum
	
end

function GGTar:nullterm( s )
	return s:match( "^[^%z]*" )
end

--- Reads the header of a block.
-- @param block The block to read.
-- @return The header data.
function GGTar:readHeaderBlock( block )
	
	local header = {}
	header.name = self:nullterm( block:sub( 1, 100 ) )
	header.mode = self:nullterm( block:sub( 101, 108 ) )
	header.uid = self:octalToNumber( self:nullterm( block:sub( 109, 116 ) ) )
	header.gid = self:octalToNumber( self:nullterm( block:sub( 117, 124 ) ) )
	header.size = self:octalToNumber( self:nullterm( block:sub( 125, 136 ) ) )
	header.mtime = self:octalToNumber( self:nullterm( block:sub( 137, 148 ) ) )
	header.chksum = self:octalToNumber( self:nullterm( block:sub( 149, 156 ) ) )
	header.typeflag = self:getTypeFlag( block:sub( 157,157 ) )
	header.linkname = self:nullterm( block:sub( 158,257 ) )
	header.magic = block:sub( 258, 263 )
	header.version = block:sub( 264, 265 )
	header.uname = self:nullterm( block:sub( 266, 297 ) )
	header.gname = self:nullterm( block:sub( 298, 329 ) )
	header.devmajor = self:octalToNumber( self:nullterm( block:sub( 330, 337 ) ) )
	header.devminor = self:octalToNumber( self:nullterm( block:sub( 338, 345 ) ) )
	header.prefix = block:sub( 346, 500 )
	
	if header.magic ~= "ustar " and header.magic ~= "ustar\0" then
		return false, "Invalid header magic " .. header.magic
	end
	
	if header.version ~= "00" and header.version ~= " \0" then
		return false, "Unknown version " .. header.version
	end
	
	if not self:checksumHeader( block ) == header.chksum then
		return false, "Failed header checksum"
	end
	
	return header

end

--- Extracts a tar archive.
-- @param filename Filename of the .tar file.
-- @param destDir Destination directory for the extracted files. Optional, default is system.DocumentsDirectory.
-- @param baseDir Base directory for the .tar file. Optional, default is system.DocumentsDirectory.
-- @param onComplete Function to be called on completion of the extraction. Optional.
function GGTar:untar( filename, destDir, baseDir, onComplete )

	if type( filename ) ~= "string" then
		return
	end
	
	local path = system.pathForFile( filename, baseDir or system.DocumentsDirectory )

	local tarHandle = open( path, "rb" )
   
   	if not tarHandle then 
   		return nil, "Error opening file " .. filename 
   	end
   
   	local longName, longLinkName
	
	while true do
		local block
		repeat 
		block = tarHandle:read( self.blocksize )
	until( not block ) or self:checksumHeader( block ) > 256
	
		if not block then 
			break 
		end
		
		local header, err = self:readHeaderBlock( block )
			
		local fileData = tarHandle:read( ceil( header.size / self.blocksize ) * self.blocksize ):sub( 1, header.size )
	
		if header.typeflag == "long name" then
			longName = self:nullterm( fileData )
		elseif header.typeflag == "long link name" then
			longLinkName = self:nullterm( fileData )
		else
		
			if longName then
				header.name = longName
				longName = nil
			end
	
			if longLinkName then
				header.name = longLinkName
				longLinkName = nil
			end
	
		end
		
		local destPath = system.pathForFile( "", destdir or system.DocumentsDirectory )

		local pathname = destPath .. "/" .. header.name
		
		if header.typeflag == "directory" then
			lfs.mkdir( pathname )
		elseif header.typeflag == "file" then
		
			local fileHandle = open( pathname, "wb" )
			
			if fileHandle then
				fileHandle:write( fileData )
				fileHandle:close()
         	end
         	
		end

	end
	
	if onComplete then
		onComplete()
	end
	
   	return true
   
end

--- Destroys this GGTar object.
function GGTar:destroy()
	self.blocksize = nil
    self.typeFlags = nil
end

return GGTar