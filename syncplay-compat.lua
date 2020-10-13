--[[
    a script to modify mpv behaviour to work best with syncplay, currently just handles local playlists
    available at: https://github.com/CogentRedTester/mpv-scripts

    Current features:

        - detects when a playlist entry has finished and seeks to time 0:00:00 before skipping to the next playlist entry

        - since the loop-playlist option breaks the above this script automatically disables the default loop-playlist behaviour
          and handles playlist looping itself. The behaviour currently replicates the "inf" setting

    set --script-opts=syncplay-enable=yes to enable this script
    this script cannot be disabled once it has been activated
]]--

local opt = require 'mp.options'
local msg = require 'mp.msg'

local o = {
    enable = false,
    inf_loop = true,
}

opt.read_options(o, 'syncplay', function() enable() end)

--sets some options when the player starts
local function set_opts()
    mp.set_property('keep-open', 'always')
    mp.set_property_bool('keep-open-pause', false)
    mp.set_property_bool('loop-playlist', false)
end

local function parse_loop(name, pref)
    msg.warn('default ' .. name .. ' handling is disabled, see script settings')
    mp.commandv('show-text', 'default ' .. name .. ' handling is disabled, see script settings', 3000)

    if pref == "no" then
        o.inf_loop = false
        return
    end
    o.inf_loop = true
    mp.set_property('loop-playlist', 'no')
end

local function playlist_next()
    local current_pos = mp.get_property_number('playlist-pos')
    local length = mp.get_property_number('playlist-count')

    if (current_pos + 1 == length) and o.inf_loop then
        if o.inf_loop then
            mp.set_property_number('playlist-pos', 0)
        else
            mp.set_property_number('percent-pos', 100)
        end
    else
        mp.command('playlist-next')
    end
end

--handles moving to next playlist entries
local function reset_time(name, eof)
    msg.debug('eof = ' .. tostring(eof))

    if eof then
        msg.verbose('moving to next playlist file')
        
        local time = mp.get_time()
        while time + 2 > mp.get_time() do end
        mp.set_property_bool('pause', true)
        mp.set_property_number('percent-pos', 0)

        while time + 3 > mp.get_time() do end
        playlist_next()

        while time+4 > mp.get_time() do end
        mp.set_property_bool('pause', false)
    end
end

function enable()
    if (o.enable) then
        msg.info('using syncplay settings')
        set_opts()
        mp.observe_property('eof-reached', "bool", reset_time)
        mp.observe_property('loop-playlist', "string", parse_loop)
    end
end

enable()