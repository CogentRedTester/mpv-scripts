--simple script which loads a music profile whenever an audio file is played

msg = require 'mp.msg'
opt = require 'mp.options'

o = {
    --valid extensions to run music-mode
    exts = 'mp3;wav;ogm;flac;m4a;wma;ogg;opus;alac;mka;aiff',

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

--splits the string into a table on the semicolons
function split(inputstr)
    local t={}
    for str in string.gmatch(inputstr, "([^;]+)") do
            table.insert(t, str)
    end
    return t
end

--returns true if the variable exists in the table
function inTable(var, table)
    for i = 1, #table, 1 do
        if (var == table[i]) then
            return true
        end
    end
    return false
end

--stores a table of the extensions
local exts = split(o.exts)

--to prevent superfluous loading of profiles the script keeps track of when music mode is enabled
local musicMode = false

local locked = false

--enabled music mode
function activate()
    msg.verbose('extension in whitelist, applying profile "' .. o.profile .. '"')
    mp.commandv('apply-profile', o.profile)
    mp.osd_message('Music Mode enabled')

    if o.show_metadata then
        show_metadata("on")
    end

    musicMode = true
end

--disables music mode
function deactivate()
    msg.verbose('extension not in whitelist, applying undo profile "' .. o.undo_profile .. '"')
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
    
    --finds the file extension
    local index = string.find(filename, [[.[^.]*$]])
    local ext = filename:sub(index + 1)
    msg.verbose('extracted extension: ' .. ext)

    --if the extension is a valid audio extension then it switches to music mode
    if inTable(ext, exts) then
        if musicMode == false then
            activate()
        end
    elseif o.undo_profile ~= "" and musicMode then
        deactivate()
    else
        msg.verbose('extension not in whitelist, doing nothing')
    end
end

--runs when the file is loaded, if script is locked it will do nothing
function fileLoaded()
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
--object modified from https://gist.github.com/AirPort/694d919b16246bc3130c8cc302415a89
metadata = {
    timer = nil,
    
	show = (function(self)
		mp.command("show-text ${filtered-metadata} 2000")
    end),
    
    start_showing = (function(self)
        msg.verbose('showing metadata')
        self:show()
        metadata.timer = mp.add_periodic_timer(2, (function () self:show() end))
    end),

    stop_showing = (function (self)
        if self.timer == nil then return end
        msg.verbose('disabling metadata')
        metadata.timer:stop()
        mp.osd_message("")
    end)
}

--changes visibility of metadata
function show_metadata(command)
    if command == "on" or command == nil then
        metadata:start_showing()
    elseif command == "off" then
        metadata:stop_showing()
    elseif command == "toggle" then
        if metadata.timer == nil or metadata.timer:is_enabled() == false then
            metadata:start_showing()
        elseif metadata.timer:is_enabled() then
            metadata:stop_showing()
        end
    else
        msg.warn('unknown command "' .. command .. '"')
    end
end

--turns music mode on
--accepts arguments: 'on', 'off', 'toggle'
mp.register_script_message('music-mode', script_message)

--stops the script from switching modes on file loads
----accepts arguments: 'on', 'off', 'toggle'
mp.register_script_message('music-mode-lock', lock_script_message)

--shows file metadata on osc
--accepts arguments: 'on' 'off' 'toggle'
mp.register_script_message('show-metadata', show_metadata)

mp.register_event('file-loaded', fileLoaded)