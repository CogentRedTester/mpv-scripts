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

    script-message save-session
    script-message reload-session

    available at: https://github.com/CogentRedTester/mpv-scripts
]]--

local mp = require 'mp'
local utils = require 'mp.utils'
local opt = require 'mp.options'
local msg = require 'mp.msg'

local o = {
    --disables the script from automatically saving the prev session
    auto_save = true,

    --runs the script automatically when started in idle mode and no files are in the playlist
    auto_load = true,

    --directory to keep a record of the previous session
    save_directory = mp.get_property('watch-later-directory', ''),

    --name of the file to save the playlist
    --save it as a .pls file to be able to open directly
    session_file = "prev-session",

    --maintain position in the playlist
    maintain_pos = true,
}

--if a specific directory has not been set then this property seems to return an empty string
if o.save_directory == "" then
    o.save_directory = "~~/watch_later"
end

opt.read_options(o, 'keep_session', function() end)

local save_file = mp.command_native({"expand-path", o.save_directory}) .. '/' .. o.session_file

--saves the current playlist as a json string
local function save_playlist()
    msg.verbose('saving current session')

    local playlist = mp.get_property_native('playlist')

    if #playlist == 0 then
        msg.verbose('session empty, aborting save')
        return
    end

    local session = io.open(save_file, 'w')
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
local function load_prev_session()
    --loads the previous session file
    msg.verbose('loading previous session')
    local session = io.open(save_file, "r+")

    --this should only occur when loading the script for the first time,
    --or if someone manually deletes the previous session file
    if session == nil or session:read() ~= "[playlist]" then
        msg.verbose('no previous session, cancelling load')
        return
    end

    local previous_playlist_pos
    local pl_start
    if o.maintain_pos then
        previous_playlist_pos = session:read()
        pl_start = mp.get_property('playlist-start')
        mp.set_property('playlist-start', previous_playlist_pos)
    end

    session:close()
    mp.commandv('loadlist', save_file)
    if o.maintain_pos then mp.set_property('playlist-start', pl_start) end
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