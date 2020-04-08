--a script to allow for local playlists to be played in syncplay

local opt = require 'mp.options'
local msg = require 'mp.msg'

local o = {
    enable = false
}

opt.read_options(o, 'syncplay')

--sets some options when the player starts
function set_opts()
    mp.set_property('keep-open', 'always')
    mp.set_property_bool('keep-open-pause', true)
end

--handles moving to next playlist entries
function reset_time(name, eof)
    msg.debug('eof = ' .. tostring(eof))

    if eof then
        local time = mp.get_time()
        while time + 2 > mp.get_time() do end
        mp.set_property_number('time-pos', 0)
        while time + 3 > mp.get_time() do end
        mp.command('playlist-next')
        while time+4 > mp.get_time() do end
        mp.set_property_bool('pause', false)
        msg.verbose('moving to next playlist file')
    end
end

if (o.enable) then
    msg.info('using syncplay settings')
    set_opts()
    mp.observe_property('eof-reached', "bool", reset_time)
end