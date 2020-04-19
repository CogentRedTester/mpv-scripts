--[[
    This script automatically saves the current playlist and reloads it if the player is started in idle mode.
    It remembers the playlist position the player was in when shutdown and reloads the playlist at that entry.
    This can be disabled with script-opts

    The script saves a text file containing the previous session playlist in the watch_later directory (changeable via opts)
    This file is saved in plaintext with the exact file paths of each playlist entry.

    The script attempts to correct relative playlist paths using the utils.join_path function. If any URL does not work
    it is probably something to do with this

    You can disable the automatic stuff and use script messages to load/save playlists as well

    script-message save-session
    script-message reload-session
]]--

local utils = require 'mp.utils'
local opt = require 'mp.options'
local msg = require 'mp.msg'

local o = {
    --disables the script from automatically saving the prev session
    auto_save = true,

    --runs the script automatically when started in idle mode and no files are in the playlist
    auto_load = true,

    --directory to keep a record of the previous session
    save_directory = mp.get_property_osd('watch-later-directory', ''),
    
    --maintain position in the playlist
    maintain_pos = true,
}

--if a specific directory has not been set then this property seems to return an empty string
if o.save_directory == "" then
    o.save_directory = "~~/watch_later"
end

opt.read_options(o, 'keep_session', function() end)

local session
local prev_session
function setup_file_associations()
    if session then return end
    msg.verbose('loading previous session file')

    --loads the previous session file
    local save_file = mp.command_native({"expand-path", o.save_directory}) .. '/prev-session.txt'
    session = io.open(save_file, "r+")

    --if the file does not exists create a new one
    if session == nil then
        msg.verbose('no session file found, creating new file')
        session = io.open(save_file, "w+")
    end
    prev_session = session:read()
    msg.debug("json of prev session: " .. prev_session)

    --reopens the file and wipes the old contents
    session:close()
    session = io.open(save_file, 'w')
end


--saves the current playlist as a json string
function save_playlist()
    msg.verbose('saving current session')

    local playlist = mp.get_property_native('playlist')
    local working_directory = mp.get_property('working-directory')

    for i, v in ipairs(playlist) do
        v.filename = utils.join_path(working_directory, v.filename)
    end
    local json, error = utils.format_json(playlist)
    session:write(json)
    session:close()
end

--sets the position of the playlist to the last session's last open file if the option is set
local previous_playlist_pos = 1
function set_position()
    if o.maintain_pos and previous_playlist_pos ~= 1 then
        mp.set_property_number('playlist-pos-1', previous_playlist_pos)
    end
end

--turns the previous json string into a table and adds all the files to the playlist
function load_prev_session()
    local t, err = utils.parse_json(prev_session)

    for i, file in ipairs(t) do
        msg.debug('adding file: ' .. file.filename)
        mp.commandv('loadfile', file.filename, "append-play")
        if o.maintain_pos and file.current then
            previous_playlist_pos = i
        end
    end
    print(utils.to_string(mp.get_property_native('playlist')))
    mp.set_property('idle', 'no')
end

--this function is for saving session manually
--it tries to setup the file associations again in case the script was disabled
function save_session()
    setup_file_associations()
    save_playlist()
end

function on_load()
    set_position()
    mp.unregister_event(on_load)
end

function reload_session()
    setup_file_associations()
    mp.command('playlist-clear')
    load_prev_session()
    mp.command('playlist-remove current')
    mp.register_event('file-loaded', on_load)
end

function shutdown()
    if o.auto_save then
        save_playlist()
    end
end


setup_file_associations()

mp.register_script_message('save-session', save_session)
mp.register_script_message('reload-session', reload_session)

mp.register_event('file-loaded', on_load)
mp.register_event('shutdown', shutdown)

--quits the rest of the script if there is no data from the previous session
if prev_session == nil or prev_session == "[]" then
    return
end

--I'm not sure if it's possible for the player to be in idle on startup with items in the playlist
--but I'm doing this to be safe
if mp.get_property_bool('idle-active', 'yes') and (mp.get_property_number('playlist-count', 0) == 0) then
    if not o.auto_load then return end
    load_prev_session()
end