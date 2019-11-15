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

    --default width and height to use when reverting the refresh rate
    default_width = 1920,
    default_height = 1080,

    --if true, sets the monitor to 2160p when the resolution of the video is greater than 1440p
    --if less the monitor will be set to the default shown above
    UHD_adaptive = false,

    --a custom display option which can be set via keybind (useful if a tv likes defaulting to 2160p 30Hz for example)
    --options are reloaded upon keypress so profiles can be used to change these values
    custom_width = "",
    custom_height = "",
    custom_refresh = 0,
    custom_refresh_key = "",

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

read_options(options, "changerefresh")


display = {
    name = "",
    number = "0",
    default_width = options.default_width,
    default_height = options.default_height,
    bdepth = "32",
    originalRate = "60",
    new_rate = "",
    new_width = "",
    new_height = "",
    estimated_fps = options.estimated_fps,
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

    local isPaused = mp.get_property_bool("pause")
    mp.set_property("pause", "yes")
    
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
    --waits 3 seconds then unpauses the video
    --prevents AV desyncs
    while (mp.get_time() - time < 3 and mp.get_property_bool("eof-reached") == false)
    do
        mp.commandv("show-text", "changing monitor " .. monitor .. " to " .. width .. "x" .. height .. " " .. rate .. "Hz")
    end
    
    display.beenReverted = false
    display.usingCustom = false

    --only unpauses if the video was not already paused
    if (isPaused == false) then
        mp.set_property("pause", "no")
    end
end

--records the properties of the currently playing video
function recordVideoProperties()
    display.new_width = mp.get_property_number('dwidth')
    display.new_height = mp.get_property_number('dheight')
    msg.log('v', "video resolution = " .. display.new_width .. "x" .. display.new_height)

    if (display.estimated_fps == true) then
        display.new_rate = mp.get_property_number('estimated-vf-fps')
    else
        display.new_rate = mp.get_property_number('container-fps')
    end
end

--records the original monitor properties
function recordMonitorProperties()
    --when passed display names nircmd seems to apply the command across all displays instead of just one
    --so to get around this the name must be converted into an integer
    --the names are in the form \\.\DISPLAY# starting from 1, while the integers start from 0
    local name = mp.get_property('display-names')
    msg.log('v', 'display list: ' .. name)
    name1 = name:find(',')
    if (name1 == nil) then
        name = name
    else
        msg.log('v', 'found comma in display list at pos ' .. tostring(name1) .. ', will use the first display')
        name = string.sub(name, 0, name1 - 1)
    end
    msg.log('v', 'display name = ' .. name)
    display.name = name
    local number = string.sub(name, -1)
    number = tonumber(number)
    number = number - 1

    display.number = number
    msg.log('v', 'display number = ' .. number)

    --if beenReverted=true, then the current rate is the original rate of the monitor
    if (display.beenReverted == true) then
        display.originalRate = mp.get_property_number('display-fps')
        msg.log('v', 'saving original fps: ' .. display.originalRate)
    end
end

function modifyDisplay()
    --high display framerates seem to vary between being just above or below the official number so proper rounding is used for the original rate
    if (display.beenReverted == true) then
        display.originalRate = math.floor(display.originalRate)
    end
end

--modifies the properties of the video to work with nircmd
function modifyVideoProperties()
    --Floor is used because 23fps video has an actual frate of ~23.9
    display.new_rate = math.floor(display.new_rate)

    display.new_width, display.new_height = width_height_modifier(display.new_width, display.new_height)
end

function width_height_modifier(width, height)

    if (options.UHD_adaptive ~= true) then
        height = display.default_height
        width = display.default_width
        return
    end

    --sets the monitor to 2160p if an UHD video is played, otherwise set to the default
    if (height < 1440) then
        height = display.default_height
        width = display.default_width
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

        changeRefresh(display.default_width, display.default_height, display.originalRate)
        display.beenReverted = true
    end
end

--toggles between using estimated and specified fps
function toggleFpsType()
    if (display.estimated_fps == true) then
        display.estimated_fps = false
        mp.commandv("show-text", "Change-Refresh now using container fps")
        msg.log('info', "now using container fps")
    else
        display.estimated_fps = true
        mp.commandv("show-text", "Change-Refresh now using estimated fps")
        msg.log('info', "now using estimated fps")
    end
end

--executes commands to switch monior to video refreshrate
function matchVideo()
    read_options(options, "changerefresh")

    --if the change is executed on a different monitor to the previous, and the previous monitor has not been been reverted
    --then revert the previous changes before changing the new monitor
    if ((display.beenReverted == false) and (display.name ~= mp.get_property('display-names'))) then
        revertRefresh()
    end

    --records the current monitor prperties and video properties
    recordMonitorProperties()
    recordVideoProperties()
    modifyVideoProperties()
    modifyDisplay()

    changeRefresh(display.new_width, display.new_height, display.new_rate)
end

--Changes the monitor to use a preset custom refreshrate
function customRefresh()
    read_options(options, "changerefresh")

    if (display.beenReverted) then
        recordMonitorProperties()
        modifyDisplay()
    end
    changeRefresh(options.custom_width, options.custom_height, options.custom_refresh)
    display.usingCustom = true
end

--sets the current (intended not actual) resoluting and refresh as the default to use upon reversion
function setDefault()
    if (display.usingCustom) then
        display.default_width = options.custom_width
        display.default_height = options.custom_height
        display.originalRate = options.custom_refresh
    else
        display.default_width = display.new_width
        display.default_height = display.new_height
        display.originalRate = display.new_rate
    end

    display.beenReverted = true
    display.usingCustom = false

    --logging chage to OSD & the console
    msg.log('info', 'set ' .. display.default_width .. "x" .. display.default_height .. " " .. display.originalRate .. "Hz as defaut display rate")
    mp.commandv('show-text', 'Change-Refresh: set ' .. display.default_width .. "x" .. display.default_height .. " " .. display.originalRate .. "Hz as defaut display rate")
end

--key tries to changeRefresh current display to match video fps
mp.add_key_binding(options.change_refresh_key, "change_refresh_rate", matchVideo)

--key reverts monitor to original refreshrate
mp.add_key_binding(options.revert_refresh_key, "revert_refresh_rate", revertRefresh)

--ket to switch between using estimated and specified fps property
mp.add_key_binding(options.toggle_fps_key, "toggle_fps_type", toggleFpsType)

--key to activate custom refresh rate
mp.add_key_binding(options.custom_refresh_key, "custom_refresh_rate", customRefresh)

--key to set the current resolution and refresh rate as the default
mp.add_key_binding(options.set_default_key, "set_default_refresh_rate", setDefault)

--reverts refresh on mpv shutdown
mp.register_event("shutdown", revertRefresh)