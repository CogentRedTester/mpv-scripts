--script to parse and play asx playlists
--this is pretty hacky to say the least, and it may not be secure since
--it uses the loadlist option.

local msg = require 'mp.msg'

mp.add_hook('on_load', 50, function()
    local path = mp.get_property('stream-open-filename')

    if path:sub(-4) ~= ".asx" then return end
    msg.info('asx playlist detected, attempting to parse')
    mp.commandv('loadlist', path)

    local playlist = mp.get_property_native('playlist')
    local ASXstr = ""
    for i, v in ipairs(playlist) do
        ASXstr = ASXstr .. v.filename
        msg.debug('reading line "' .. v.filename .. '"')
    end

    mp.command('playlist-clear')
    for url in ASXstr:gmatch('<ref href=.-/>') do
        msg.debug('found ' .. url .. ' in file')
        local urlstart = url:find("['\"]")
        url = url:sub(urlstart + 1)
        local urlend = url:find("['\"]")
        url = url:sub(1, urlend - 1)

        msg.verbose('adding "' .. url .. '" to playlist')
        mp.commandv('loadfile', url, "append")
    end
    mp.command('playlist-remove current')
end)