--[[
	A simple script which loads a music profile whenever an audio file is played.
	An audio file is a file in which entry 1 in the track list is an audio stream, or albumart
	There is also an option to set an 'undo' profile for when video files are loaded whilst in music mode

	Profiles are only ever applied when switching between audio or video files, so you can change
	settings while listening to a playlist and not have them be reset each track as long as the files are either
	all audio, or all video.

	The script assumes the file will be a video, so the undo profile will not be run on startup.

	The script also adds a few script messages, one to enable/disable/toggle music mode,
	one to lock the script so that it doesn't update automatically, and one to print file metadata to the screen.
	Names and argument options are at the bottom of this script file.
]]--

local msg = require 'mp.msg'
local opt = require 'mp.options'

--script options, set these in script-opts
o = {
    --change to disable automatic mode switching
    auto = true,

    --profile to call when valid extension is found
    profile = "music",

    --runs this profile when in music mode and a non-audio file is loaded
    --you should essentially put all your defaults that the music profile changed in here
    undo_profile = "",

    --start playback in music mode. This setting is only applied when the player is initially started,
    --changing this option during runtime does nothing.
    --probably only useful if auto is disabled
    enable = false,

    --dispays the metadata of the track on the osd when music mode is on
    --there is also a script message to enable this seperately
    show_metadata = false
}

opt.read_options(o, 'musicmode', function() msg.verbose('options updated') end)

--a music file is one where mpv returns an audio stream as the first track
function is_audio_file()
    if mp.get_property('track-list/0/type') == "audio" then
        return true
    elseif mp.get_property('track-list/0/albumart') == "yes" then
        return true
    end
    return false
end

--to prevent superfluous loading of profiles the script keeps track of when music mode is enabled
local musicMode = false

--enables music mode
function activate()
    mp.commandv('apply-profile', o.profile)
    mp.osd_message('Music Mode enabled')

    if o.show_metadata then
        show_metadata("on")
    end

    musicMode = true
end

--disables music mode
function deactivate()
    mp.commandv('apply-profile', o.undo_profile)
    mp.osd_message('Music Mode disabled')

    if o.show_metadata then
        show_metadata('off')
    end

    musicMode = false
end

function main()
    --if the file is an audio file then the music profile is loaded
    if is_audio_file() then
        msg.verbose('audio file, applying profile "' .. o.profile .. '"')
        if not musicMode then
            activate()
        end
    elseif o.undo_profile ~= "" and musicMode then
        msg.verbose('video file, applying undo profile "' .. o.undo_profile .. '"')
        deactivate()
    end
end

--sets music mode from script-message
function script_message(command)
    if command == "on" or command == nil then
        activate()
    elseif command == "off" then
        deactivate()
    elseif command == "toggle" then
        if musicMode then
            deactivate()
        else
            activate()
        end
    else
        msg.warn('unknown command "' .. command .. '"')
    end
end

function lock()
    o.auto = false
    msg.info('Music Mode locked')
    mp.osd_message('Music Mode locked')
end

function unLock()
    o.auto = true
    msg.info('Music Mode unlocked')
    mp.osd_message('Music Mode unlocked')
end

--toggles lock
function lock_script_message(command)
    if command == "on" or command == nil then
        lock()
    elseif command == "off" then
        unLock()
    elseif command == "toggle" then
        if o.auto then
            lock()
        else
            unLock()
        end
    else
        msg.warn('unknown command "' .. command .. '"')
    end
end

local metadata = mp.create_osd_overlay('ass-events')
metadata.hidden = not o.show_metadata

function update_metadata()
    metadata.data = mp.get_property_osd('filtered-metadata')
end

function enable_metadata()
    metadata.hidden = false
    metadata:update()
end

function disable_metadata()
    metadata.hidden = true
    metadata:update()
end

--changes visibility of metadata
function show_metadata(command)
    if command == "on" or command == nil then
        enable_metadata()
    elseif command == "off" then
        disable_metadata()
    elseif command == "toggle" then
        if metadata.hidden then
            enable_metadata()
        else
            disable_metadata()
        end
    else
        msg.warn('unknown command "' .. command .. '"')
    end
end

--runs when the file is loaded, if script is locked it will do nothing
function file_loaded()
    update_metadata()
    metadata:update()
    if o.auto then
        main()
    end
end

if o.enable then
    activate()
end

--sets music mode
--accepts arguments: 'on', 'off', 'toggle'
mp.register_script_message('music-mode', script_message)

--stops the script from switching modes on file loads
----accepts arguments: 'on', 'off', 'toggle'
mp.register_script_message('music-mode-lock', lock_script_message)

--shows file metadata on osc
--accepts arguments: 'on' 'off' 'toggle'
mp.register_script_message('show-metadata', show_metadata)

mp.register_event('file-loaded', file_loaded)
