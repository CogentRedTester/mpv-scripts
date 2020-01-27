--[[
	A simple script which loads a music profile whenever an audio file is played.
	An audio file is one with no video track, or when its video track has an fps < 2 (an image file).
	There is also an option to set an 'undo' profile for when video files are loaded whilst in music mode

	Profiles are only ever applied when switching between audio or video files, so you can change
	settings while listening to a playlist and not have them be reset each track as long as the files are either
	all audio, or all video.

	The script assumes the file will be a video, so the undo profile will not be run on startup.

	The script also adds a few script messages, one to enable/disable/toggle music mode,
	one to lock the script so that it doesn't update automatically, and one to print file metadata to the screen.
	Names and argument options are at the bottom of this script file.
]]--

msg = require 'mp.msg'
opt = require 'mp.options'

o = {
    --profile to call when valid extension is found
    profile = "music",

    --runs this profile when in music mode and a non-audio file is loaded
    --you should essentially put all your defaults that the music profile changed in here
    undo_profile = "",

    --dispays the metadata of the track on the osd when music mode is on
    --there is also a script message to enable this seperately
    show_metadata = false
}

opt.read_options(o, 'musicmode')

--a music file has no video track, or the video track is less than 2 fps (an image file)
function is_audio_file()
    if mp.get_property_number('vid', 0) == 0 then
        return true
    else
        if mp.get_property_number('container-fps', 0) < 2 and mp.get_property_number('aid', 0) ~= 0 then
            return true
        end
    end
    return false
end

--to prevent superfluous loading of profiles the script keeps track of when music mode is enabled
local musicMode = false

local locked = false

--enabled music mode
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
    --finds the filename
    local filename = mp.get_property('filename')
    msg.verbose('"' .. filename .. '" loaded')

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

--runs when the file is loaded, if script is locked it will do nothing
function file_loaded()
    if locked == false then
        main()
    end
end
 
--toggles music mode
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
    locked = true
    msg.info('Music Mode locked')
    mp.osd_message('Music Mode locked')
end

function unLock()
    locked = false
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
        if locked then
            unLock()
        else
            lock()
        end
    else
        msg.warn('unknown command "' .. command .. '"')
    end
end

--manages timer to show metadata on osd
--object based on: https://gist.github.com/AirPort/694d919b16246bc3130c8cc302415a89
local metadata = {
    timer = nil,
    
	show = (function(self)
		mp.command("show-text ${filtered-metadata} 2000")
    end),
    
    start_showing = (function(self)
        msg.verbose('showing metadata')
        self:show()
        self.timer:resume()
    end),

    stop_showing = (function (self)
        msg.verbose('disabling metadata')
        self.timer:stop()
        mp.osd_message("")
    end)
}

metadata.timer = mp.add_periodic_timer(2, (function () metadata:show() end))
metadata.timer:stop()

--changes visibility of metadata
function show_metadata(command)
    if command == "on" or command == nil then
        metadata:start_showing()
    elseif command == "off" then
        metadata:stop_showing()
    elseif command == "toggle" then
        if metadata.timer:is_enabled() == false then
            metadata:start_showing()
        elseif metadata.timer:is_enabled() then
            metadata:stop_showing()
        end
    else
        msg.warn('unknown command "' .. command .. '"')
    end
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
