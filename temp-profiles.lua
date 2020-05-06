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
    enable = true,
    timeout = 2,
}

local opt = require 'mp.options'
local msg = require 'mp.msg'
local timers = {}

opt.read_options(o, 'temp_profiles', function(list) update_opts(list) end)

function apply_profile(profile, undo_profile, timeout)
    if not o.enable then return end

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


mp.add_hook('on_unload', 50, function()
    for profile, timer in pairs(timers) do
        timer:kill()
        undo_profile(profile)
    end
end)

--update options
function update_opts(list)
    if list.enable then
        if not o.enable then
            for profile, timer in pairs(timers) do
                if timer:is_enabled() then
                    undo_profile(profile)
                end
            end
        end
    end
end
update_opts({timeout = true, enable = true})