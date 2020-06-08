--[[
    This script dynamically changes some settings at runtime while playing files over the ftp protocol

    Settings currently changed:

        - converts filepaths taken directly from a browser into a string format readable by mpv
            -e.g. "ftp://test%20ing" would become "ftp://test ing"

        - detects when ftp subtitle files are incorrrectly loaded and attempts to re-add them using the corrected filepath

        - if a directory is loaded it attempts to open a playlist file inside it (default is playlist.pls)
        
        - ordered chapters are loaded from a playlist file in the source directory (default is playlist.pls)
]]--

local opt = require 'mp.options'
local msg = require 'mp.msg'

--add options using script-opts=ftpopts-option=value
local o = {
    force_enable = false,

    directory_playlist = 'playlist.pls',
    ordered_chapter_playlist = 'playlist.pls',

    --if true the script will always check warning messages to see if one is about an ftp sub file
    --if false the script will only keep track of warning messages when already playing an ftp file
    --essesntially if this is false you can't drag an ftp sub file onto a non ftp video stream
    always_check_subs = true
}

opt.read_options(o, 'ftp_compat')

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

--runs all of the custom parsing operations for ftp filenames
function fixFtpPath()
    --converts the path into a valid string
    path = path:gsub([[\]],[[/]])
    path = decodeURI(path)

    --if there is no period in the filename then the file is actually a directory
    local filename = path:sub(path:find("/[^/]*$") + 1)
    if not filename:find('%.') then
        msg.info('directory loaded, attempting to load playlist file')
        path = path .. "/" .. o.directory_playlist
    end

    mp.set_property('stream-open-filename', path)
end

--sets the custom ftp options
--only applies to the specific file loaded
--since this function needs to be rerun for every ftp file anyway,
--this doesn't decrease performance
function setFTPOpts()
    msg.verbose('setting custom options for ' .. path)
    local directory = path:sub(1, path:find("/[^/]*$"))

    --sets ordered chapters to use a playlist file inside the directory
    mp.set_property('file-local-options/ordered-chapters-files', directory .. '/' .. o.ordered_chapter_playlist)
end

--converts the URL of an errored subtitle and tries adding it again
function parseMessage(event)
    if (not ftp) and (not o.always_check_subs) then return end

    local error = event.text
    if not error:find("Can not open external file ") then return end

    --isolating the file that was added
    sub = error:sub(28, -3)
    if sub:find("s?ftp://") ~= 1 then return end

    --modifying the URL
    local originalSub = sub
    sub = decodeURI(sub)

    --if this sub was not modified, then cancel the function
    --otherwise this would cause an infinite loop if the path is actually wrong
    if (sub == originalSub) then
        msg.verbose('revised sub file was still not valid, cancelling event loop')
        return
    end
    msg.info('attempting to add revised file address')
    mp.commandv('sub-add', sub)
    prevSub = sub
end

--tests if the file being opened uses the ftp protocol to set custom settings
function testFTP()
    msg.verbose('checking for ftp protocol')
    path = mp.get_property('stream-open-filename')

    if o.force_enable or path:find("s?ftp://") == 1 then
        msg.info('FTP protocol detected, modifying settings')
        ftp = true
        fixFtpPath()
        setFTPOpts()
        return
    end
    ftp = false
end

--scans warning messages to tell if a subtitle track was incorrectly added
mp.enable_messages('error')
mp.register_event('log-message', parseMessage)

--testFTP doesn't strictly need to be a hook, but I don't want it to run asynchronously with fixFtpPath
mp.add_hook('on_load', 50, testFTP)