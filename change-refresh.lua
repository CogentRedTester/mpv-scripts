--[[]
This script uses nircmd to change the refresh rate of the display that the mpv window is currently open in
This was written because I could not get autospeedwin to work :(

If the display does not support the specified resolution or refresh rate it will silently fail, this script
is designed to be used with televisions that support the full range of media refresh rates (23, 24, 29, 30, 59, 60)

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
    --options are reloaded upon keypress so profiles can be used to change this
    custom_width = "",
    custom_height = "",
    custom_refresh = "",
    custom_refresh_key = "",

    --keys to change and revert the monitor
    change_refresh_key = "f10",
    revert_refresh_key = "Ctrl+f10",

    --key to switch between estimated and specified fps
    toggle_fps_key = "",

    --sets the resolution and refresh rate of the currently modified monitor to be the default
    set_default_key = "",
}

read_options(options, "changerefresh")


videoProperties = {
    ["height"] = "",
    ["width"] = "",
    ["rate"] = "",
    ["estimated"] = options.estimated_fps
}

monitorProperties = {
    ["name"] = "",
    ["number"] = "0",
    ["width"] = options.default_width,
    ["height"] = options.default_height,
    ["bdepth"] = "32",
    ["originalRate"] = "60",
    ["rate"] = "60",
    ["beenReverted"] = true,
    ["usingCustom"] = false,
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
    local monitor = monitorProperties.number
    msg.log('v', 'calling nircmd with command: ' .. options.nircmd)
    msg.log('v', 'changing display: ' .. monitorProperties.name)
    msg.log('v', 'current refresh = ' .. mp.get_property('display-fps'))

    msg.log('info', "changing monitor " .. monitor .. " to " .. width .. "x" .. height .. " " .. rate .. "Hz")
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
            [6] = "32",
            [7] = tostring(rate)
        }
    })
    --waits 3 seconds then unpauses the video
    --prevents AV desyncs
    while (mp.get_time() - time < 3)
    do
        mp.commandv("show-text", "changing monitor " .. monitor .. " to " .. width .. "x" .. height .. " " .. rate .. "Hz")
    end
    
    monitorProperties.beenReverted = false
    monitorProperties.usingCustom = false
    mp.set_property("pause", "no")
end

--records the properties of the currently playing video
function recordVideoProperties()
    videoProperties.width = mp.get_property_number('dwidth')
    msg.log('v', "video width = " .. videoProperties.width)
    videoProperties.height = mp.get_property_number('dheight')
    msg.log('v', "video height = " .. videoProperties.height)

    if (options.estimated_fps == true) then
        videoProperties.rate = mp.get_property_number('estimated-vf-fps')
    else
        videoProperties.rate = mp.get_property_number('container-fps')
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
    msg.log('v', 'found comma in display list at pos ' .. tostring(name1) .. ', will use the first display')
    if (name1 == nil) then
        name = name
    else
        name = string.sub(name, 0, name1 - 1)
    end
    msg.log('v', 'display name = ' .. name)
    monitorProperties.name = name
    local number = string.sub(name, -1)
    number = tonumber(number)
    number = number - 1

    monitorProperties.number = number
    msg.log('v', 'display number = ' .. number)

    --if beenReverted=true, then the current rate is the original rate of the monitor
    if (monitorProperties.beenReverted == true) then
        monitorProperties.originalRate = mp.get_property_number('display-fps')
        msg.log('v', 'saving original fps: ' .. monitorProperties.originalRate)
    end
end

--modifies the properties of the video to work with nircmd
function modifyVideoProperties()
    --Floor is used because 23fps video has an actual frate of ~23.9
    videoProperties.rate = math.floor(videoProperties.rate)

    --high display framerates seem to vary between being just above or below the official number so proper rounding is used for the original rate
    if (monitorProperties.beenReverted == true) then
        monitorProperties.originalRate = round(monitorProperties.originalRate)
    end

    if (options.UHD_adaptive ~= true) then
        videoProperties.height = monitorProperties.height
        videoProperties.width = monitorProperties.width
        return
    end

    --sets the monitor to 2160p if an UHD video is played, otherwise set to the default
    if (videoProperties.height < 1440) then
        videoProperties.height = monitorProperties.height
        videoProperties.width = monitorProperties.width
    else
        videoProperties.height = 2160
        videoProperties.width = 3840
    end
end

--reverts the monitor to its original refresh rate
function revertRefresh()
    if (monitorProperties.beenReverted == false) then
        changeRefresh(monitorProperties.width, monitorProperties.height, monitorProperties.originalRate)
        monitorProperties.beenReverted = true
    end
end

--toggles between using estimated and specified fps
function toggleFpsType()
    if (videoProperties.estimated_fps == true) then
        videoProperties.estimated_fps = false
        mp.commandv("show-text", "Change-Refresh now using container fps")
        msg.log('info', "now using container fps")
    else
        videoProperties.estimated_fps = true
        mp.commandv("show-text", "Change-Refresh now using estimated fps")
        msg.log('info', "now using estimated fps")
    end
end

--executes commands to switch monior to video refreshrate
function matchVideo()
    read_options(options, "changerefresh")

    --if the change is executed on a different monitor to the previous, and the previous monitor has not been been reverted
    --then revert the previous changes before changing the new monitor
    if ((monitorProperties.beenReverted == false) and (monitorProperties.name ~= mp.get_property('display-names'))) then
        revertRefresh()
    end

    --saves the current refreshrate of the monitor
    local currentRate = math.floor(mp.get_property_number('display-fps'))

    --records the current monitor prperties and video properties
    recordMonitorProperties()
    recordVideoProperties()

    modifyVideoProperties()

    --if the new refresh rate of the monitor is not the same as the current refresh rate, then execute the change command
    if (videoProperties.rate ~= currentRate) then
        changeRefresh(videoProperties.width, videoProperties.height, videoProperties.rate)
    end
end

--Changes the monitor to use a preset custom refreshrate
function customRefresh()
    read_options(options, "changerefresh")
    changeRefresh(options.custom_width, options.custom_height, options.custom_refresh)
    monitorProperties.usingCustom = true
end

--sets the current (intended not actual) resoluting and refresh as the default to use upon reversion
function setDefault()
    if (monitorProperties.usingCustom) then
        monitorProperties.width = options.custom_width
        monitorProperties.height = options.custom_height
        monitorProperties.originalRate = options.custom_refresh
    else
        monitorProperties.width = videoProperties.width
        monitorProperties.height = videoProperties.height
        monitorProperties.originalRate = videoProperties.rate
    end

    monitorProperties.beenReverted = true
    monitorProperties.usingCustom = false

    --logging chage to OSD & the console
    msg.log('info', 'set ' .. monitorProperties.width .. "x" .. monitorProperties.height .. " " .. monitorProperties.originalRate .. "Hz as defaut display rate")
    mp.commandv('show-text', 'Change-Refresh: set ' .. monitorProperties.width .. "x" .. monitorProperties.height .. " " .. monitorProperties.originalRate .. "Hz as defaut display rate")
end

--key tries to changeRefresh current display to match video fps
mp.add_key_binding(options.change_refresh_key, "change_refresh_rate", matchVideo)

--key reverts monitor to original refreshrate
mp.add_key_binding(options.revert_refresh_key, "revert_refresh_rate", revertRefresh)

--ket to switch between using estimated and specified fps property
mp.add_key_binding(options.toggle_fps_key, "toggle_fps_type", toggleFpsType)

mp.add_key_binding(options.custom_refresh_key, "custom_refresh_rate", customRefresh)

mp.add_key_binding(options.set_default_key, "set_default_refresh_rate", setDefault)

--reverts refresh on mpv shutdown
mp.register_event("shutdown", revertRefresh)