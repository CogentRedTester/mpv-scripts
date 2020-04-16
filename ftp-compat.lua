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
    directory_playlist = 'playlist.pls',
    ordered_chapter_playlist = 'playlist.pls',

    --if true the script will always check warning messages to see if one is about an ftp sub file
    --if false the script will only keep track of warning messages when already playing an ftp file
    --essesntially if this is false you can't drag an ftp sub file onto a non ftp video stream
    always_check_subs = true
}

opt.read_options(o, 'ftp_compat')

local originalOpts = {
    ordered_chapters = ""
}
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
    if not ftp then return end
    msg.info('invalid ftp path, attempting to correct')

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
    
    --has to run ftp opts again so that it uses the corrected file paths
    setFTPOpts()
end

--sets the custom ftp options
function setFTPOpts()
    msg.verbose('setting custom options for ' .. path)
    local directory = path:sub(1, path:find("/[^/]*$"))

    --sets ordered chapters to use a playlist file inside the directory
    mp.set_property('ordered-chapters-files', directory .. '/' .. o.ordered_chapter_playlist)
end

--reverts options to before the ftp protocol was used
function revertOpts()
    msg.info('reverting settings to default')
    mp.set_property('ordered-chapters-files', originalOpts.ordered_chapters)
end

--saves the original options to revert when no-longer playing an ftp file
function saveOpts()
    msg.verbose('saving original option values')
    originalOpts.ordered_chapters = mp.get_property('ordered-chapters-files')
end

--stores the previous sub so that we can detect infinite file loops caused by a
--completely invalid URL
local prevSub

--converts the URL of an errored subtitle and tries adding it again
function parseMessage(event)
    if (not ftp) and (not o.always_check_subs) then return end

    local error = event.text
    if not error:find("Can not open external file ") then return end

    --isolating the file that was added
    sub = error:sub(28, -3)
    if sub:find("ftp://") ~= 1 then return end

    --modifying the URL
    sub = decodeURI(sub)

    --if this sub was the same as the prev, then cancel the function
    --otherwise this would cause an infinite loop
    --this is different behaviour from mpv default since you can't add the same file twice in a row
    --but I don't know of any reason why one would do that, so I'm leaving it like this
    if (sub == prevSub) then
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
    prevSub = ""

    if path:find("ftp://") == 1 then
        if not ftp then saveOpts() end

        msg.info('FTP protocol detected, modifying settings')
        ftp = true
        setFTPOpts()
        return
    elseif ftp then
        revertOpts()
    end
    ftp = false
end

--scans warning messages to tell if a subtitle track was incorrectly added
mp.enable_messages('error')
mp.register_event('log-message', parseMessage)

mp.add_hook('on_load', 50, testFTP)
mp.add_hook('on_load_fail', 50, fixFtpPath)