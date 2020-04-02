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
local replacingFile = false

--decodes a URL address
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

function setFTPOpts()
    msg.verbose('FTP protocol detected')
    ftp = true
    path = mp.get_property('path')

    --converts the path into a valid string
    path = path:gsub([[\]],[[/]])
    path = decodeURI(path)

    local directory = path:sub(1, path:find("/[^/]*$"))
    local filename = path:sub(path:find("/[^/]*$") + 1)
    local playlist = directory .. 'playlist.pls'

    --if there is no period in the filename then the file is actually a directory
    if not filename:find('%.') then
        msg.verbose('directory loaded - attempting to load playlist file')
        --if the filename is nill, then the path ends with a /
        if filename == nil then
            path = path .. o.directory_playlist
        else
            path = path .. "/" .. o.directory_playlist
        end
    end

    --reloads the file, replacing the old one, 
    if path ~= mp.get_property('path') then
        local pos = mp.get_property_number('playlist-pos')
        mp.commandv('playlist-remove', pos)
        mp.commandv('loadfile', path, 'append-play')
        replacingFile = true
    end
    --mp.set_property
    mp.set_property('ordered-chapters-files', playlist)
end

--tests if the file being opened uses the ftp protocol
function testFTP()
    --reloading a file with corrected addresses causes this function to be rerun.
    --this check prevents the function from being run twice for each file
    if replacingFile then
        replacingFile = false
        msg.verbose('skipping ftp configuration because script reloaded same file')
        return
    end

    ftp = false
    msg.verbose('checking for ftp protocol')
    path = mp.get_property('path')
    msg.verbose("got past here")
    local protocol = path:sub(1, 3)
    if protocol == "ftp" then
        setFTPOpts()
    end

end

local prevSub
local subChanging = false

--converts the URL of an errored subtitle and tries adding it again
function addSubtitle(sub)
    --removing the main error message
    sub = sub:gsub("Can not open external file ", "")

    --removing the space and period at the end of the message
    sub = sub:sub(1, -3)
    sub = decodeURI(sub)

    --if this sub was the same as the prev and the addition was not successful, then cancel the function
    --otherwise this would cause an infinite loop
    if (sub == prevSub) and subChanging then
        print(subChanging)
        msg.verbose('revised sub file was still not valid - cancelling event loop')
        return
    end
    mp.commandv('sub-add', sub)
    subChanging = true
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

--tracks if the subtitle addition was successful
function trackChange()

    subChanging = false
    msg.verbose('track changed')
end

mp.observe_property('track-list', nil, trackChange)

--scans warning messages to tell if a subtitle track was incorrectly added
mp.enable_messages('warn')
mp.register_event('log-message', parseMessage)

mp.register_event('start-file', testFTP)