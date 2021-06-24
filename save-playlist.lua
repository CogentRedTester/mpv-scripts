--[[
    A script for saving m3u playlists based on mpvs current internal playlist.
    Users can set the name and directory to save the file in the initial script message,
    or can enter custom strings in the osd.
    Available at: https://github.com/CogentRedTester/mpv-scripts

    To support requesting user input this script requires that the script mpv-user-input be
    loaded by mpv in the ~~/scripts directory, and that user-input-module is in the ~~/script-modules directory.
    mpv-user-input is available here: https://github.com/CogentRedTester/mpv-user-input

    Syntax:
        script-message save-playlist [directory] [filename] [flags]

        If the directory and/or filename are missing, or are empty strings, then the user will be
        prompted for input. The filename will be appended with the .m3u extension.
        The flags are a string of options

    Flags:
        Currently there is only one flag: `relative`
        When relative is passed to the script the playlist will use paths relative to the saved playlist.
        This is currently very primitive, and only works with files that are children of the save directory.
]]--

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"

local input = dofile(mp.command_native({"expand-path", "~~/script-modules/user-input-module.lua"}))
local working = mp.get_property("working-directory", "")

local function save_playlist(directory, name, relative)
    if not directory or not name then return end
    directory = mp.command_native({"expand-path", directory})
    local path = directory.."/"..name..".m3u"
    local file = io.open(path, "w")
    if not file then msg.error("could not open file '"..path.."' for writing") ; return end

    local playlist = mp.get_property_native("playlist")
    for _, item in ipairs(playlist) do
        local path = item.filename

        if not path:find("^%a+://") then
            path = utils.join_path(working, path)
            path = path:gsub("\\", "/")
            path = path:gsub("/./", "/")

            if relative then
                local _, finish = path:find(directory, 1, true)
                if finish then path = path:sub(finish+1) end
            end
        end

        msg.verbose("wrote", '"'..path..'"', "to playlist")
        file:write(path.."\n")
    end
    msg.info("Saved", #playlist, "files to", '"'..directory..'"')
    mp.osd_message("Saved "..(#playlist).." files to playlist")
    file:close()
end

local function handle_save_request(directory, name, relative)
    local need_dir = not directory or directory == ""
    local need_name = not name or name == ""
    relative = relative == "relative"

    if need_dir then
        input.get_user_input(function(res)
            if not need_name then save_playlist(res, name, relative)
            else directory = res end
        end, {id = "dir", text = "Enter save directory:"})
    end

    if need_name then
        input.get_user_input(function(res)
            save_playlist(directory, res, relative)
        end, {id = "name", text = "Enter playlist name:"})
    end
end

mp.add_key_binding("Ctrl+p", "save-playlist", handle_save_request)
