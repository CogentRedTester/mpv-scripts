--[[
    This script dynamically changes some settings at runtime when playing files over te ftp protocol

    Settings currently changed:
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

opt.read_options(o, 'ftp-opts')

local path

function setFTPOpts()
    msg.verbose('FTP protocol detected')
    path = path:gsub([[\]],[[/]])

    local directory = path:sub(1, path:find("/[^/]*$"))
    --local filename = path:sub(path:find("/[^/]*$") + 1)
    local playlist = directory .. 'playlist.pls'

    --mp.set_property
    mp.set_property('ordered-chapters-files', playlist)

end

function testFTP()
    if o.ftp then setFTPOpts() end

    if not o.test_protocol then return end
    msg.verbose('checking for ftp protocol')
    path = mp.get_property('path')
    local protocol = path:sub(1, 3)
    if protocol == "ftp" then
        o.ftp = true
        setFTPOpts()
    end

end

mp.register_event('start-file', testFTP)