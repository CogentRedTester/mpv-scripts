--[[
    This script dynamically changes some settings at runtime while playing files over the ftp protocol
    available at: https://github.com/CogentRedTester/mpv-scripts

    Settings currently changed:

        - converts filepaths taken directly from a browser into a string format readable by mpv
            -e.g. "ftp://test%20ing" would become "ftp://test ing"

        - if a directory is loaded it attempts to open a playlist file inside it (default is .folder.m3u)
]]--

local mp = require 'mp'
local opt = require 'mp.options'
local msg = require 'mp.msg'

--add options using script-opts=ftp_compat-option=value
local o = {
    directory_playlist = '.folder.m3u',
}

opt.read_options(o, 'ftp_compat')

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
local function fixFtpPath()
    --converts the path into a valid string
    path = path:gsub([[\]],[[/]])
    path = decodeURI(path)

    --if the path ends in a '/' then we consider it a directory
    if not path:match("/[^/]+$") then
        msg.info('directory loaded - attempting to load playlist file')
        path = path .. o.directory_playlist
    end

    mp.set_property('stream-open-filename', path)
end

--tests if the file being opened uses the ftp protocol to set custom settings
local function testFTP()
    msg.verbose('checking for ftp protocol')
    path = mp.get_property('stream-open-filename')

    if path:find("ftp://") == 1 then
        msg.info('ftp protocol detected - attempting to fix path')
        fixFtpPath()
    end
end

--attempts to fix the path on mpv fail
mp.add_hook('on_load_fail', 50, testFTP)

--script messages for loading ftp tracks as external files
mp.register_script_message('ftp/video-add', function(path, flags)
    if flags then
        mp.commandv('video-add', decodeURI(path), flags)
    else
        mp.commandv('video-add', decodeURI(path))
    end
end)

mp.register_script_message('ftp/audio-add', function(path,flags)
    if flags then
        mp.commandv('audio-add', decodeURI(path), flags)
    else
        mp.commandv('audio-add', decodeURI(path))
    end
end)

mp.register_script_message('ftp/sub-add', function(path,flags)
    if flags then
        mp.commandv('sub-add', decodeURI(path), flags)
    else
        mp.commandv('sub-add', decodeURI(path))
    end
end)