--[[
    This script is designed to allow you to apply a temporary profile,
    the original use case was for tempoarily changing the OSD style on mouse click (for my music mode)

    The script is controlled through script messages:
        script-message temp-profile [profile] [undo-profile] [timeout]

    The undo profile is applied when the timeout runs out, the timeout is optional, if you leave it blank the script
    will use the default timeout.

    Note that while the base functionality of this script is fully working, it is still very much in progress, so
    the options and commands may change at any time.
]]--

local o = {
    timeout = 2,
    disabled = '[]'
}

local opt = require 'mp.options'
local msg = require 'mp.msg'
local utils = require 'mp.utils'
local timers = {}
local disabled_json = utils.parse_json(o.disabled)
local disabled = {box = true}
for i,v in ipairs(disabled_json) do
    disabled[v] = true
end

opt.read_options(o, 'temp_profiles')

function apply_profile(profile, undo_profile, timeout)
    if disabled[profile] then return end

    msg.debug('recieved input')
    if timeout == nil then timeout = o.timeout end
    if timers[profile] == nil then
        timers[profile] = mp.add_timeout(timeout, function()
            msg.verbose('applying undo profile ' .. undo_profile)
            mp.commandv('apply-profile', undo_profile)
            timers[profile]:kill()
        end)
    elseif timers[profile]:is_enabled() then
        timers[profile]:kill()
        timers[profile]:resume()
        return
    end
    msg.verbose('applying profile: ' .. profile)
    mp.commandv('apply-profile', profile)

    timers[profile].timeout = timeout
    timers[profile]:resume()
end

function undo_profile(profile)
    msg.verbose('applying undo profile ' .. profile)
    mp.commandv('apply-profile', profile)
    timers[profile]:kill()
end

mp.register_script_message('temp-profile', apply_profile)

mp.register_script_message('disable-temp-profile', function(profile)
    disabled[profile] = true
end)
mp.register_script_message('enable-temp-profile', function(profile)
    disabled[profile] = false
end)


mp.add_hook('on_unload', 50, function()
    for profile, timer in pairs(timers) do
        timer:kill()
        undo_profile(profile)
    end
end)