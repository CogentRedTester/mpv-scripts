--[[
    This script is designed to allow you to apply a temporary profile,
    the original use case was for tempoarily changing the OSD style on mouse click (for my music mode)
    available at: https://github.com/CogentRedTester/mpv-scripts

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

local mp = require 'mp'
local opt = require 'mp.options'
local msg = require 'mp.msg'

local timers = {}
local active_timers = {}

opt.read_options(o, 'temp_profiles')

--specific profile commands are stored in a table with the following structure:
--t[profile] = {undo = 'undo_profile', timer = mp.add_timeout('timeout'), undo_funct = function()...end}
local function apply_profile(profile, undo_profile, timeout)
    msg.debug('recieved input')
    if timeout == nil then timeout = o.timeout end
    if undo_profile == nil then undo_profile = "" end
    if timers[profile] == nil then timers[profile] = {} end
    local p = timers[profile]
    p.undo = undo_profile

    if p.timer == nil then
        p.undo_funct = function()
            msg.verbose('applying undo profile ' .. p.undo)
            mp.commandv('apply-profile', p.undo)
            p.timer:kill()
            active_timers[profile] = nil
        end
        p.timer = mp.add_timeout(timeout, p.undo_funct)

    elseif p.timer:is_enabled() then
        p.timer.timeout = timeout
        p.timer:kill()
        p.timer:resume()
        return
    end

    msg.verbose('applying profile: ' .. profile)
    mp.commandv('apply-profile', profile)
    p.timer.timeout = timeout
    p.timer:resume()
    active_timers[profile] = p
end

mp.register_script_message('temp-profile', apply_profile)

--undoes all of the profiles when the file ends
mp.add_hook('on_unload', 50, function()
    for _, profile in pairs(active_timers) do
        if profile.timer:is_enabled() then
            profile.undo_funct()
        end
    end
end)

--this is to drain property changes before the next file starts
mp.add_hook('on_after_end_file', 50, function() end)