--simple script which loads a music profile whenever an audio file is played and forces the OSC to update it's layout
--this requires my modified osc.lua function and script message in order to work

msg = require 'mp.msg'
opt = require 'mp.options'

o = {
    exts = 'mp3;wav;ogm;flac;m4a;wma;ogg;opus;alac;mka',
    profile = "music",

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
local inMusicMode = false

function main()
    --finds the filename
    local filename = mp.get_property('filename')
    msg.verbose(filename .. 'loaded')
    
    --finds the file extension
    local index = string.find(filename, [[.[^.]*$]])
    local ext = filename:sub(index + 1)
    msg.verbose('extracted extension: ' .. ext)

    --if the extension is a valid audio extension then it switches to music mode
    if inTable(ext, exts) and inMusicMode == false then
        msg.verbose('extension in whitelist, applying profiles')
        mp.commandv('apply-profile', o.profile)
        mp.commandv('script-message', 'update-osc-options')

        inMusicMode = true
    elseif inMusicMode then
        msg.verbose('extension not in whitelist, applying undo profiles')
        mp.commandv('apply-profile', o.undo_profile)
        mp.commandv('script-message', 'update-osc-options')

        inMusicMode = false
    end
end

mp.register_event('file-loaded', main)