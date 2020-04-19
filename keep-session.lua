local utils = require 'mp.utils'
local opt = require 'mp.options'

local o = {
    --enable the script
    enable = true,

    --directory to keep a record of the previous session
    save_directory = mp.get_property_osd('watch-later-directory', ''),
    
    --maintain position in the playlist
    maintain_pos = true,
}

--if a specific directory has not been set then this property seems to return an empty string
if o.save_directory == "" then
    o.save_directory = "~~/watch_later"
end

opt.read_options(o, 'keep_session')

local session
local prev_session
function setup_file_associations()
    if session then return end

    --loads the previous session file
    local save_file = mp.command_native({"expand-path", o.save_directory}) .. '/prev-session.txt'
    session = io.open(save_file, "r+")

    --if the file does not exists create a new one
    if session == nil then
        session = io.open(save_file, "w+")
    end
    prev_session = session:read()

    --reopens the file and wipes the old contents
    session:close()
    session = io.open(save_file, 'w')
end

--saves the current playlist as a json string
function save_playlist()
    local playlist = mp.get_property_native('playlist')
    local working_directory = mp.get_property('working-directory')

    for i, v in ipairs(playlist) do
        v.filename = utils.join_path(working_directory, v.filename)
    end
    local json, error = utils.format_json(playlist)
    session:write(json)
    session:close()
end

--this function is for saving session manually
--it tries to setup the file associations again in case the script was disabled
function save_session()
    setup_file_associations()
    save_playlist()
end

mp.register_script_message('save-session', save_session)

--quits the whole script if the options is set to be disabled
if not o.enable then
    return
end

--sets the position of the playlist to the last session's last open file if the option is set
local previous_playlist_pos = 1
function set_position()
    if o.maintain_pos and previous_playlist_pos ~= 1 then
        mp.set_property_number('playlist-pos-1', previous_playlist_pos)
    end

    --we only want this to run once
    mp.unregister_event(set_position)
end


setup_file_associations()

mp.register_event('file-loaded', set_position)
mp.register_event('shutdown', save_playlist)


--quits the rest of the script if there is no data from the previous session
if prev_session == nil or prev_session == "[]" then
    return
end

--turns the previous json string into a table and adds all the files to the playlist
--is not a function as it only runs when the player first boots up
--I'm not sure if it's possible for the player to be in idle on starytup with items in the playlist
--but I'm doing this to be safe
if mp.get_property_bool('idle-active', 'yes') and (mp.get_property_number('playlist-count', 0) == 0) then
    --print(utils.parse_json(prev_session))
    local t, err = utils.parse_json(prev_session)

    for i, file in ipairs(t) do
        mp.commandv('loadfile', file.filename, "append")
        if o.maintain_pos and file.current then
            previous_playlist_pos = i
        end
    end
    mp.set_property('idle', 'no')
end