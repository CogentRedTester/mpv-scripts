--[[
    This script dynamically changes some settings at runtime when playing files over te ftp protocol

    Settings currently changed:

        - converts filepaths taken directly from a browser into a string format readable by mpv
            -e.g. "ftp://test%20ing" would become "ftp://test ing"

        - detects when ftp subtitle files are incorrrectly loaded and attempts to re-add them using the corrected filepath

        - if a directory is loaded it attempts to open a playlist file inside it (default is playlist.pls)
        
        - ordered chapters are loaded from a playlist file in the source directory (default is playlist.pls)
]]--

local opt = require 'mp.options'
local msg = require 'mp.msg'

local o = {
    directory_playlist = 'playlist.pls',
    ordered_chapter_playlist = 'playlist.pls',
}

opt.read_options(o, 'ftp-opts', function() msg.debug('options updated') end)

local ftp = false
local path

--decodes a URL address
--this piece of code was taken from: https://stackoverflow.com/questions/20405985/lua-decodeuri-luvit/20406960#20406960
local decodeURI
do
    local char, gsub, tonumber = string.char, string.gsub, tonumber
    local function _(hex) return char(tonumber(hex, 16)) end

    function decodeURI(s)
        msg.debug('decoding string: ' .. s)
        s = gsub(s, '%%(%x%x)', _)
        msg.debug('returning string: ' .. s)
        return s
    end
end

--runs all of the custom operations for ftp files
function setFTPOpts()
    msg.info('FTP protocol detected - modifying settings')

    --converts the path into a valid string
    path = path:gsub([[\]],[[/]])
    path = decodeURI(path)

    local directory = path:sub(1, path:find("/[^/]*$"))
    local filename = path:sub(path:find("/[^/]*$") + 1)

    --sets ordered chapters to use a playlist file inside the directory
    mp.set_property('ordered-chapters-files', directory .. '/' .. o.ordered_chapter_playlist)

    --if there is no period in the filename then the file is actually a directory
    if not filename:find('%.') then
        msg.info('directory loaded - attempting to load playlist file')
        path = path .. "/" .. o.directory_playlist
    end

    --reloads the file, replacing the old one
    --does not run if decodeURI did not change any characters in the address
    if path ~= mp.get_property('path') then
        msg.info('attempting to reload file with corrected path')
        local pos = mp.get_property_number('playlist-pos')
        local endPlaylist = mp.get_property_number('playlist-count', 0)
        mp.commandv('loadfile', path, 'append')
        mp.commandv('playlist-move', endPlaylist, pos+1)
        mp.commandv('playlist-remove', pos)
    end
end

--stores the previous sub so that we can detect infinite file loops caused by a
--completely invalid URL
local prevSub

--converts the URL of an errored subtitle and tries adding it again
function addSubtitle(sub)
    --removing the main error message
    sub = sub:gsub("Can not open external file ", "")

    --removing the space and period at the end of the message
    sub = sub:sub(1, -3)
    sub = decodeURI(sub)

    --if this sub was the same as the prev, then cancel the function
    --otherwise this would cause an infinite loop
    --this is different behaviour from mpv default since you can't add the same file twice in a row
    --but I don't know of any reason why one would do that, so I'm leaving it like this
    if (sub == prevSub) then
        msg.verbose('revised sub file was still not valid - cancelling event loop')
        return
    end
    msg.info('attempting to add revised file address')
    mp.commandv('sub-add', sub)
    prevSub = sub
end

--only passes the warning if it matches the desired format
function parseMessage(event)
    if not ftp then return end

    local error = event.text
    if error:find("Can not open external file ") then
        addSubtitle(error)
    end
end

--tests if the file being opened uses the ftp protocol
function testFTP()
    --reloading a file with corrected addresses causes this function to be rerun.
    --this check prevents the function from being run twice for each file
    if path == mp.get_property('path') then
        msg.verbose('skipping ftp configuration because script reloaded same file')
        return
    end

    ftp = false
    path = mp.get_property('path')

    msg.verbose('checking for ftp protocol')
    local protocol = path:sub(1, 3)
    if protocol == "ftp" then
        ftp = true
        setFTPOpts()
    end
end

--scans warning messages to tell if a subtitle track was incorrectly added
mp.enable_messages('warn')
mp.register_event('log-message', parseMessage)

mp.register_event('start-file', testFTP)