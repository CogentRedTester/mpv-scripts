--[[
    This script automatically saves the current playlist and can reload it if the player is started in idle mode (specifically
    if there are 0 files in the playlist), or if the correct command is sent via script-messages.
    It remembers the playlist position the player was in when shutdown and reloads the playlist at that entry.
    This can be disabled with script-opts

    The script saves a text file containing the previous session playlist in the watch_later directory (changeable via opts)
    This file is saved in plaintext with the exact file paths of each playlist entry.
    Note that since it uses the same file, only the latest mpv window to be closed will be saved

    The script attempts to correct relative playlist paths using the utils.join_path function. I've tried to automatically
    detect when any non-files are loaded (if it has the sequence :// in the path), so that it'll work with URLs

    You can disable the automatic stuff and use script messages to load/save playlists as well

    script-message save-session [session-file]
    script-message reload-session [session-file] [load_playlist]

    If not included `session-file` will use the default file specified in script-opts.
    `load_playlist` controls whether the whole playlist should be restored or just the one file,
    the value can be `yes` or `no`. If not included it defaults to the value of the `load_playlist` script opt.

    available at: https://github.com/CogentRedTester/mpv-scripts
]]--

local mp = require 'mp'
local utils = require 'mp.utils'
local opt = require 'mp.options'
local msg = require 'mp.msg'

local o = {
    --automatically save the prev session
    auto_save = true,

    --runs the script automatically when started in idle mode and no files are in the playlist
    auto_load = true,

    --reloads the full playlist from the previous session
    --can be individually overwritten when sending script-messages
    load_playlist = true,

    --file path of the default session file
    --save it as a .pls file to be able to open directly (though it will not maintain the playlist positions)
    session_file = "",

    --maintain position in the playlist
    --does nothing if load_playlist is disabled
    maintain_pos = true,
}

opt.read_options(o, 'keep_session', function() end)

--sets the default session file to the watch_later directory or ~~/watch_later/
if o.session_file == "" then
    local watch_later = mp.get_property('watch-later-directory', "")
    if watch_later == "" then watch_later = "~~state/watch_later/" end
    if not watch_later:find("[/\\]$") then watch_later = watch_later..'/' end

    o.session_file = watch_later.."prev-session"
end
local save_file = mp.command_native({"expand-path", o.session_file})

--saves the current playlist as a json string
local function save_playlist(file)
    if not file then file = save_file end
    msg.verbose('saving current session to', file)

    local playlist = mp.get_property_native('playlist')

    if #playlist == 0 then
        msg.verbose('session empty, aborting save')
        return
    end

    local session = io.open(file, 'w')
    if not session then return msg.error("Failed to write to file", file) end

    session:write("[playlist]\n")
    session:write(mp.get_property('playlist-pos') .. "\n")

    local working_directory = mp.get_property('working-directory')
    for _, v in ipairs(playlist) do
        msg.debug('adding ' .. v.filename .. ' to playlist')

        --if the file is available then it attempts to expand the path in-case of relative playlists
        --presumably if the file contains a protocol then it shouldn't be expanded
        if not v.filename:find("^%a*://") then
            v.filename = utils.join_path(working_directory, v.filename)
            msg.debug('expanded path: ' .. v.filename)
        end

        session:write("File=" .. v.filename .. "\n")
    end
    session:close()
end

--turns the previous json string into a table and adds all the files to the playlist
local function load_prev_session(file, load_playlist)
    if not file or file == '' then file = save_file end

    if load_playlist == 'yes' then load_playlist = true
    elseif load_playlist == 'no' then load_playlist = false
    else load_playlist = o.load_playlist end

    --loads the previous session file
    msg.verbose('loading previous session from', file)
    local session = io.open(file, "r+")

    --this should only occur when loading the script for the first time,
    --or if someone manually deletes the previous session file
    if session == nil or session:read() ~= "[playlist]" then
        msg.verbose('no previous session, cancelling load')
        if session then session:close() end
        return
    end

    local previous_playlist_pos = session:read('*n')

    if load_playlist then
        msg.debug('reloading playlist')

        if not o.maintain_pos then
            mp.commandv('loadlist', file)
        else
            local prev_playlist_start = mp.get_property('playlist-start')
            msg.verbose("restoring playlist position", previous_playlist_pos)
            mp.set_property_number('playlist-start', previous_playlist_pos)

            mp.commandv('loadlist', file)

            -- restore the original value unless the `playlist-start` property has been otherwise modified
            if mp.get_property_number('playlist-start') ~= previous_playlist_pos then
                mp.set_property('playlist-start', prev_playlist_start)
            end
        end
    else
        msg.debug('discarding playlist')
        local files = {}
        for line in session:lines() do
            table.insert(files, string.match(line, 'File=(.+)'))
        end

        -- mpv and keep-session uses 0 based array indices, but lua uses 1-based
        mp.commandv('loadfile', files[previous_playlist_pos+1])
    end

    session:close()
end

local function shutdown()
    if o.auto_save then
        save_playlist()
    end
end

mp.register_script_message('save-session', save_playlist)
mp.register_script_message('reload-session', load_prev_session)
mp.register_event('shutdown', shutdown)

--Load the previous session if auto_load is enabled and the playlist is empty
--the function is not called until the first property observation is triggered to let everything initialise
--otherwise modifying playlist-start becomes unreliable
if o.auto_load and (mp.get_property_number('playlist-count', 0) == 0) then
    local function temp()
        load_prev_session()
        mp.unobserve_property(temp)
    end
    mp.observe_property("idle", "string", temp)
end
