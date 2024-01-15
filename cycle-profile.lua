--[[
    script to cycle profiles with a keybind, accomplished through script messages
    available at: https://github.com/CogentRedTester/mpv-scripts

    syntax:
        script-message cycle-profiles "profile1;profile2;profile3"

    You must use semicolons to separate the profiles, do not include any spaces that are not part of the profile name.
    The script will print the profile description to the screen when switching, if there is no profile description, then it just prints the name
]]--

local mp = require 'mp'
local msg = require 'mp.msg'

--table of all available profiles and options
local profile_map = {}

--keeps track of current profile for every unique cycle
local iterators = {}

local function setup_profile_list()
    local profile_list = mp.get_property_native('profile-list', {})

    for _, profile in ipairs(profile_list) do
        profile_map[profile.name] = profile
    end
end

local function main(...)
    local profiles = {...}
    local key = table.concat(profiles, ';')
    local prev_iterator = iterators[key]

    if iterators[key] == nil then
        msg.debug('unknown cycle, creating iterator')
        iterators[key] = 1
    else
        iterators[key] = iterators[key] + 1
        if iterators[key] > #profiles then iterators[key] = 1 end
    end

    --converts the string into an array of profile names
    msg.verbose('cycling ' .. tostring(profiles))
    msg.verbose("number of profiles: " .. tostring(#profiles))

    local prevProfile = profiles[prev_iterator]
    local newProfile = profiles[iterators[key]]

    if prev_iterator and profile_map[prevProfile] and profile_map[prevProfile]['profile-restore'] then
        msg.info('restoring profile', prevProfile)
        mp.commandv('apply-profile', prevProfile, 'restore')
    end

    if newProfile == '' then
        mp.osd_message('restoring profiles')
        return
    end

    --sends the command to apply the profile
    msg.info("applying profile", newProfile)
    mp.commandv('apply-profile', newProfile)

    --prints the profile description to the OSD
    local desc = profile_map[newProfile]['profile-desc'] or newProfile
    msg.verbose('profile description:', desc)
    mp.osd_message(desc)
end

setup_profile_list()
mp.register_script_message('cycle-profiles', main)