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
}

local opt = require 'mp.options'
local msg = require 'mp.msg'

local t = {}

opt.read_options(o, 'temp_profiles')

--specific profile commands are stored in a table with the following structure:
--t[profile] = {undo = 'undo_profile', timer = mp.add_timeout('timeout')}
function apply_profile(profile, undo_profile, timeout)
    msg.debug('recieved input')
    if timeout == nil then timeout = o.timeout end
    if undo_profile == nil then undo_profile = "" end
    if t[profile] == nil then t[profile] = {} end
    t[profile].undo = undo_profile

    if t[profile].timer == nil then
        t[profile].timer = mp.add_timeout(timeout, function()
            msg.verbose('applying undo profile ' .. t[profile].undo)
            mp.commandv('apply-profile', t[profile].undo)
            t[profile].timer:kill()
        end)
    elseif t[profile].timer:is_enabled() then
        t[profile].timer.timeout = timeout
        t[profile].timer:kill()
        t[profile].timer:resume()
        return
    end
    msg.verbose('applying profile: ' .. profile)
    mp.commandv('apply-profile', profile)
    t[profile].timer.timeout = timeout
    t[profile].timer:resume()
end

function undo_profile(profile)
    msg.verbose('applying undo profile ' .. t[profile].undo)
    mp.commandv('apply-profile', t[profile].undo)
    t[profile].timer:kill()
end

mp.register_script_message('temp-profile', apply_profile)

mp.add_hook('on_unload', 50, function()
    for profile, timer in pairs(t) do
        undo_profile(profile)
    end
end)