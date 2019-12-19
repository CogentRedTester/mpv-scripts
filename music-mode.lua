--simple script which loads a music profile whenever an audio file is played and forces the OSC to update it's layout
--this requires my modified osc.lua function and script message in order to work

msg = require 'mp.msg'
opt = require 'mp.options'

o = {
    exts = 'mp3;wav;ogm;flac;m4a;wma;ogg;opus;alac;mka',
    profile = "music"
}

opt.read_options(o, 'music_mode')

function main()
    local filename = mp.get_property('filename')
    msg.verbose(filename .. 'loaded')
    
    local index = string.find(filename, [[.[^.]*$]])
    local ext = filename:sub(index + 1)
    msg.verbose('extracted extension: ' .. ext)

    if (o.exts:match(ext)) then
        msg.verbose('extension in whitelist, applying profiles')
        mp.commandv('apply-profile', o.profile)
        mp.commandv('script-message', 'update-osc-options')
    end
end

mp.register_event('file-loaded', main)