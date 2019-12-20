--simple script which loads a music profile whenever an audio file is played and forces the OSC to update it's layout
--this requires my modified osc.lua function and script message in order to work

msg = require 'mp.msg'
opt = require 'mp.options'

o = {
    --valid extensions to run music-mode
    exts = 'mp3;wav;ogm;flac;m4a;wma;ogg;opus;alac;mka',

    --profile to call when valid extension is found
    profile = "music",

    --runs this profile when in music mode and a non-audio file is loaded
    --you should essentially put all your defaults that the music profile changed in here
    undo_profile = ""
}

opt.read_options(o, 'music_mode')

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

    musicMode = true
end

--disables music mode
function deactivate()
    msg.verbose('extension not in whitelist, applying undo profile "' .. o.undo_profile .. '"')
    mp.commandv('apply-profile', o.undo_profile)
    mp.osd_message('Music Mode disabled')

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
function toggle()
    if musicMode then
        deactivate()
    else
        activate()
    end
end

--toggles lock
function lock()
    if locked then
        locked = false
        msg.info('music mode unlocked')
        mp.osd_message('music mode unlocked')
    else
        locked = true
        msg.info('music mode locked')
        mp.osd_message('music mode locked')
    end
end

--toggles music mode on and off
mp.register_script_message('music-mode-toggle', toggle)

--stops the script from switching modes on file loads
mp.register_script_message('music-mode-lock', lock)

--switches music mode on
mp.register_script_message('music-mode', activate)

mp.register_event('file-loaded', fileLoaded)