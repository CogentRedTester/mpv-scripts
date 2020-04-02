--[[
    This script dynamically changes some settings at runtime when playing files over te ftp protocol

    Settings currently changed:
        - converts filepaths taken directly from a browser into a string format readable by mpv
            -e.g. "ftp://test%20ing" would become "ftp://test ing"
        - ordered chapters are loaded from a playlist file in the source directory
]]--

local opt = require 'mp.options'
local msg = require 'mp.msg'

local o = {
    ftp = false,
    --directory_playlist = 'playlist.pls',
    ordered_chapter_playlist = 'playlist.pls',
    
    --tests for the ftp protocol by looking at the start of the path string
    --is not necessary if using an auto-profile (protocol.ftp) to set the above ftp option
    test_protocol = true,
}

opt.read_options(o, 'ftp-opts', function() msg.debug('options updated') end)

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
    path = mp.get_property('path')

    msg.verbose('FTP protocol detected')
    path = path:gsub([[\]],[[/]])
    path = decodeURI(path)

    local directory = path:sub(1, path:find("/[^/]*$"))
    --local filename = path:sub(path:find("/[^/]*$") + 1)
    local playlist = directory .. 'playlist.pls'

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

function testFTP()
    if replacingFile then
        replacingFile = false
        msg.verbose('skipping ftp configuration because script reloaded same file')
        return
    end

    if o.ftp then
        setFTPOpts()
        return
    end

    if not o.test_protocol then return end
    msg.verbose('checking for ftp protocol')
    path = mp.get_property('path')
    msg.verbose("got past here")
    local protocol = path:sub(1, 3)
    if protocol == "ftp" then
        o.ftp = true
        setFTPOpts()
    end

end

mp.register_event('start-file', testFTP)