--[[
This script uses nircmd to change the refresh rate of the display that the mpv window is currently open in
This was written because I could not get autospeedwin to work :(

If the display does not support the specified resolution or refresh rate it will silently fail
If the video refresh rate does not match any on the whitelist it will pick the next highest.
If the video fps is higher tha any on the whitelist it will pick the highest available

This script is idealy used with televisions that support the full range of media refresh rates (23, 24, 25, 29, 30, 59, 60, etc)

The script will keep track of the original refresh rate of the monitor and revert when either the
correct keybind is pressed, or when mpv exits.

The script is currently hardcoded to set a resolution of 1920x1080p for videos with a height of < 1440 pixels,
and 3840x2160p for any height larger

you can also send refresh change commands using script messages:
script-message set-display-rate [width] [height] [rate]
--]]


utils = require 'mp.utils'
msg = require 'mp.msg'
require 'mp.options'

--options available through --script-opts=changerefresh-[option]=value
local options = {
    --the location of nircmd.exe, tries to use the %Path% by default
    nircmd = "nircmd",

    --list of valid refresh rates, separated by semicolon, listed in ascending order
    --this whitelist also applies when attempting to revert the display, so include that rate in the list
    --nircmd only seems to work with integers, DO NOT use the full refresh rate, i.e. 23.976
    rates = "23;24;25;29;30;50;59;60",

    --set whether to use the estimated fps or the container fps
    --see https://mpv.io/manual/master/#command-interface-container-fps for details
    estimated_fps = false,

    --automatically detect monitor resolution when switching
    --will use this resolution when reverting changes
    detect_monitor_resolution = true,

    --default width and height to use when reverting the refresh rate
    --ony used if detect_monitor_resolution is false
    original_width = 1920,
    original_height = 1080,

    --if true, sets the monitor to 2160p when the resolution of the video is greater than 1440p
    --if less the monitor will be set to the default shown above
    UHD_adaptive = false,

    --keys to change and revert the monitor
    --all keys are configurable via script-binding in input.conf, see bottom of script for the names
    change_refresh_key = "f10",
    revert_refresh_key = "Ctrl+f10",

    --key to switch between estimated and specified fps
    toggle_fps_key = "",

    --sets the resolution and refresh rate of the currently modified monitor to be the default
    --useful in conjunction with custom rate settings
    set_default_key = "",
}

function updateOptions()
    msg.log('v', 'updating options')
    read_options(options, "changerefresh")
end

display = {
    name = "",
    number = "0",
    original_width = options.original_width,
    original_height = options.original_height,
    bdepth = "32",
    original_fps = "60",
    new_fps = "",
    new_width = "",
    new_height = "",
    beenReverted = true,
    usingCustom = false,
}

function round(value)
    if (value % 1 >= 0.5) then
        value = math.ceil(value)
    else
        value = math.floor(value)
    end

    return value
end

--calls nircmd to change the display resolution and rate
function changeRefresh(width, height, rate)
    local closestRate
    rate = tonumber(rate)

    --picks either the same fps in the whitelist, or the next highest
    --if none of the whitelisted rates are higher, then it uses the highest
    for validRates in string.gmatch(options.rates, "[%w.]+") do
        validRates = tonumber(validRates)
        closestRate = validRates
        if (rate <= validRates) then
            break
        end
    end
    rate = closestRate

    local monitor = display.number
    msg.log('v', 'calling nircmd with command: ' .. options.nircmd)
    msg.log('v', 'changing display: ' .. display.name)
    msg.log('v', 'current refresh = ' .. mp.get_property('display-fps'))

    msg.log('info', "changing monitor " .. monitor .. " to " .. width .. "x" .. height .. " " .. rate .. "Hz")

    --pauses the video while the change occurs to avoid A/V desyncs
    local isPaused = mp.get_property_bool("pause")
    mp.set_property_bool("pause", true)
    
    local time = mp.get_time()
    utils.subprocess({
        ["cancellable"] = false,
        ["args"] = {
            [1] = options.nircmd,
            [2] = "setdisplay",
            [3] = "monitor:" .. tostring(monitor),
            [4] = tostring(width),
            [5] = tostring(height),
            [6] = display.bdepth,
            [7] = tostring(rate)
        }
    })
    --waits 3 seconds before continuing or until eof/player exit
    while (mp.get_time() - time < 3 and mp.get_property_bool("eof-reached") == false)
    do
        mp.commandv("show-text", "changing monitor " .. monitor .. " to " .. width .. "x" .. height .. " " .. rate .. "Hz")
    end
    
    display.beenReverted = false

    --sets the video to the original pause state
    mp.set_property_bool("pause", isPaused)
end

--records the properties of the currently playing video
function recordVideoProperties()
    display.new_width = mp.get_property_number('dwidth')
    display.new_height = mp.get_property_number('dheight')
    msg.log('v', "video resolution = " .. display.new_width .. "x" .. display.new_height)

    --saves either the estimated or specified fps of the video
    if (options.estimated_fps == true) then
        display.new_fps = mp.get_property_number('estimated-vf-fps')
    else
        display.new_fps = mp.get_property_number('container-fps')
    end
end

--finds the display resolution by going into fullscreen and grabbing the resolution of the OSD
--this is seemingly the easiest way to get the true screen reolution
--if detect_screen_resolution is disabled this won't be required
function getDisplayResolution()
    local isFullscreen = mp.get_property_bool('fullscreen')

    mp.set_property_bool('fullscreen', true)
    local width = mp.get_property("osd-width")
    local height = mp.get_property("osd-height")

    mp.set_property_bool("fullscreen", isFullscreen)

    return width, height
end

--records the original monitor properties
function recordDisplayProperties()
    --when passed display names nircmd seems to apply the command across all displays instead of just one
    --so to get around this the name must be converted into an integer
    --the names are in the form \\.\DISPLAY# starting from 1, while the integers start from 0
    local name = mp.get_property('display-names')
    msg.log('v', 'display list: ' .. name)

    --if a comma is in the list the mpv window is on mutiple displays
    name1 = name:find(',')
    if (name1 == nil) then
        name = name
    else
        msg.log('v', 'found comma in display list at pos ' .. tostring(name1) .. ', will use the first display')

        --the display-fps property always refers to the first display in the display list
        --so we must extract the first name from the list
        name = string.sub(name, 0, name1 - 1)
    end

    msg.log('v', 'display name = ' .. name)
    display.name = name

    --the last character in the name will always be the display number
    --we extract the integer and subtract by 1, as nircmd starts from 0
    local number = string.sub(name, -1)
    number = tonumber(number)
    number = number - 1

    display.number = number
    msg.log('v', 'display number = ' .. number)

    --if beenReverted=true, then the current display settings are the original and we must save them again
    if (display.beenReverted == true) then
        --saves the actual resolution if option set, otherwise uses the defaults
        if options.detect_monitor_resolution then
            display.original_width, display.original_height = getDisplayResolution()
        end

        display.original_fps = math.floor(mp.get_property_number('display-fps'))
        msg.log('v', 'saving original fps: ' .. display.original_fps)
    end
end

--modifies the properties of the video to work with nircmd
function modifyVideoProperties()
    --Floor is used because 23fps video has an actual frate of ~23.9
    display.new_fps = math.floor(display.new_fps)

    display.new_width, display.new_height = getModifiedWidthHeight(display.new_width, display.new_height)
end

function getModifiedWidthHeight(width, height)

    if (options.UHD_adaptive ~= true) then
        height = display.original_height
        width = display.original_width
        return
    end

    --sets the monitor to 2160p if an UHD video is played, otherwise set to the default
    if (height < 1440) then
        height = display.original_height
        width = display.original_width
    else
        height = 2160
        width = 3840
    end
    msg.log('v', "setting display to: " .. width .. "x" .. height)

    return width, height
end

--reverts the monitor to its original refresh rate
function revertRefresh()
    if (display.beenReverted == false) then
        msg.log('v', "reverting refresh rate")

        changeRefresh(display.original_width, display.original_height, display.original_fps)
        display.beenReverted = true
    else
        msg.log('v', "aborting reversion, display has not been changed")
    end
end

--toggles between using estimated and specified fps
--does so by modifying the script-opt list and reloading options
function toggleFpsType()
    local script_opts = mp.get_property("options/script-opts")
    
    if (string.find(script_opts, "changerefresh%-estimated_fps=") == nil) then
        msg.log('v', 'toggling estimated fps - no script-opt found adding option')
        script_opts = script_opts .. ",changerefresh-estimated_fps=no"
    end

    if (options.estimated_fps == true) then
        script_opts = script_opts:gsub("changerefresh%-estimated_fps=yes", "changerefresh%-estimated_fps=no")

        mp.commandv("show-text", "Change-Refresh now using container fps")
        msg.log('info', "now using container fps")
    else
        script_opts = script_opts:gsub("changerefresh%-estimated_fps=no", "changerefresh%-estimated_fps=yes")

        mp.commandv("show-text", "Change-Refresh now using estimated fps")
        msg.log('info', "now using estimated fps")
    end
    
    mp.set_property("options/script-opts", script_opts)
end

--executes commands to switch monior to video refreshrate
function matchVideo()
    --if the change is executed on a different monitor to the previous, and the previous monitor has not been been reverted
    --then revert the previous changes before changing the new monitor
    if ((display.beenReverted == false) and (display.name ~= mp.get_property('display-names'))) then
        revertRefresh()
    end

    --records the current monitor prperties and video properties
    recordDisplayProperties()
    recordVideoProperties()
    modifyVideoProperties()

    changeRefresh(display.new_width, display.new_height, display.new_fps)
end

--sets the current (intended not actual) resoluting and refresh as the default to use upon reversion
function setDefault()
    display.original_width, display.original_height = getDisplayResolution()
    display.original_fps = math.floor(mp.get_property_number('display-fps'))

    display.beenReverted = true

    --logging change to OSD & the console
    msg.log('info', 'set ' .. display.original_width .. "x" .. display.original_height .. " " .. display.original_fps .. "Hz as defaut display rate")
    mp.commandv('show-text', 'Change-Refresh: set ' .. display.original_width .. "x" .. display.original_height .. " " .. display.original_fps .. "Hz as defaut display rate")
end

--key tries to changeRefresh current display to match video fps
mp.add_key_binding(options.change_refresh_key, "change_refresh_rate", matchVideo)

--key reverts monitor to original refreshrate
mp.add_key_binding(options.revert_refresh_key, "revert_refresh_rate", revertRefresh)

--ket to switch between using estimated and specified fps property
mp.add_key_binding(options.toggle_fps_key, "toggle_fps_type", toggleFpsType)

--key to set the current resolution and refresh rate as the default
mp.add_key_binding(options.set_default_key, "set_default_refresh_rate", setDefault)

--sends a command to switch to the specified display rate
--syntax is: script-message set-display-rate [width] [height] [fps]
mp.register_script_message("set-display-rate", changeRefresh)

--updates options from script-opts whenever script-opts changes
mp.observe_property("options/script-opts", nil, updateOptions)

--reverts refresh on mpv shutdown
mp.register_event("shutdown", revertRefresh)