--[[
This script uses nircmd to change the refresh rate of the display that the mpv window is currently open in
This was written because I could not get autospeedwin to work :(

If the display does not support the specified resolution or refresh rate it will silently fail
If the video refresh rate does not match any on the whitelist it will pick the next highest.
If the video fps is higher tha any on the whitelist it will pick the highest available
The whitelist is specified via the script-opt rates. Valid rates are separated via semicolons, do not include spaces and list in asceding order.
You can also set a custom display rate for individual video rates using a hyphen, for example:
    script-opts=changerefresh-rates="23;24;25-50;30;60"
This will change the display to 23, 24, and 30 fps when playing videos in those same rates, but will change the display to 50 fps when
playing videos in 25 Hz

This script is idealy used with displays that support the full range of media refresh rates (23, 24, 25, 29, 30, 59, 60, etc)

The script will keep track of the original refresh rate of the monitor and revert when either the
correct keybind is pressed, or when mpv exits. The original rate needs to be included on the whitelist, but if the rate is
hyphenated, it will ignore the switched rate and just use the original

The script is able to find the current resolution of the monitor and will always use those dimensions when switching refresh rates,
however I have an UHD mode (UHD adaptive) hardcoded to use a resolution of 3840x2160p for videos with a height of > 1440 pixels.

It is also possible to disable automatic monitor resolution detection and use manual values (see options below).
The detection is done via switching to fullscreen mode and grabbing the resolution of the OSD, so it can be disabled if one finds it annoying.

you can also send refresh change commands using script messages:
    script-message set-display-rate [width] [height] [rate]

these manual changes bypass the whitelist and rate associations and are sent to nircmd directly, so make sure you send a valid integer
--]]

utils = require 'mp.utils'
msg = require 'mp.msg'
require 'mp.options'

--options available through --script-opts=changerefresh-[option]=value
--all of these options can be changed at runtime using profiles, the script will automatically update
local options = {
    --the location of nircmd.exe, tries to use the %Path% by default
    nircmd = "nircmd",

    --list of valid refresh rates, separated by semicolon, listed in ascending order
    --by adding a hyphen after a number you can set a custom display rate for that specific video rate:
    --  "23;24;25-50;60"  Will set the display to 50fps for 25fps videos
    --this whitelist also applies when attempting to revert the display, so include that rate in the list
    --nircmd only seems to work with integers, DO NOT use the full refresh rate, i.e. 23.976
    rates = "23;24;25;29;30;50;59;60",

    --change refresh automatically on startup
    auto = false,

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
}

var = {
    dname = "",
    dnumber = "0",
    original_width = options.original_width,
    original_height = options.original_height,
    bdepth = "32",
    original_fps = "60",
    new_fps = "",
    new_width = "",
    new_height = "",
    beenReverted = true,
    usingCustom = false,
    rateList = {},
    rates = {}
}

--is run whenever a change in script-opts is detected
function updateOptions()
    msg.verbose( 'updating options')
    read_options(options, "changerefresh")
    checkRatesString()
    updateTable()
end

--checks if the rates string contains any invalid characters
function checkRatesString()
    local str = options.rates
    
    str = str:gsub(";", '')
    str = str:gsub("%-", '')

    if str:match("%D") then
        print ('rates whitelist contains invalid characters, can only contain numbers, semicolons and hyphens')
    end
end

--creates an array of valid video rates and a map of display rates to switch to
function updateTable()
    msg.verbose("updating tables of valid rates")
    for rate in string.gmatch(options.rates, "[^;]+") do
        msg.debug("found option: " .. rate)
        if rate:match("-") then
            msg.debug("contains hyphen, extracting custom rates")

            local originalRate = rate:gsub("-.*$", "")
            msg.debug("-originalRate = " .. originalRate)

            local newRate = rate:gsub(".*-", "")
            msg.debug("-customRate = " .. newRate)

            originalRate = tonumber(originalRate)
            newRate = tonumber(newRate)

            --tests for nil values caused by missing rates on either side of hyphens
            if originalRate == nil and newRate == nil then
                msg.debug('-no rates found, ignoring')
                goto loopend
            end

            if originalRate == nil then
                msg.info("missing rate before hyphen in whitelist, ignoring option")
                goto loopend
            end
            if newRate == nil then
                msg.info("missing rate after hyphen in whitelist")
                msg.info("ignoring and setting " .. rate .. " to " .. originalRate)
                newRate = originalRate
            end
            var.rates[originalRate] = newRate
            rate = originalRate
        else
            rate = tonumber(rate)
            var.rates[rate] = rate
        end
        table.insert(var.rateList, rate)

        ::loopend::
    end
end

--calls nircmd to change the display resolution and rate
function changeRefresh(width, height, rate)
    msg.verbose( 'calling nircmd with command: ' .. options.nircmd)
    msg.verbose( 'changing display: ' .. var.dname)
    msg.verbose( 'current refresh = ' .. mp.get_property('display-fps'))

    msg.info( "changing monitor " .. var.dnumber .. " to " .. width .. "x" .. height .. " " .. rate .. "Hz")

    --pauses the video while the change occurs to avoid A/V desyncs
    local isPaused = mp.get_property_bool("pause")
    mp.set_property_bool("pause", true)
    
    local time = mp.get_time()
    utils.subprocess({
        ["cancellable"] = false,
        ["args"] = {
            [1] = options.nircmd,
            [2] = "setdisplay",
            [3] = "monitor:" .. tostring(var.dnumber),
            [4] = tostring(width),
            [5] = tostring(height),
            [6] = var.bdepth,
            [7] = tostring(rate)
        }
    })
    --waits 3 seconds before continuing or until eof/player exit
    while (mp.get_time() - time < 3 and mp.get_property_bool("eof-reached") == false)
    do
        mp.commandv("show-text", "changing monitor " .. var.dnumber .. " to " .. width .. "x" .. height .. " " .. rate .. "Hz")
    end
    
    var.beenReverted = false

    --sets the video to the original pause state
    mp.set_property_bool("pause", isPaused)
end

--finds the display resolution by going into fullscreen and grabbing the resolution of the OSD
--this is seemingly the easiest way to get the true screen resolution
--if detect_screen_resolution is disabled this won't be required
function getDisplayResolution()
    local isFullscreen = mp.get_property_bool('fullscreen')

    mp.set_property_bool('fullscreen', true)
    local width = mp.get_property("osd-width")
    local height = mp.get_property("osd-height")

    msg.verbose('original monitor resolution = ' .. tostring(width) .. 'x' .. tostring(height))

    mp.set_property_bool("fullscreen", isFullscreen)

    return width, height
end

--Finds the name of the display mpv is currently running on
--when passed display names nircmd seems to apply the command across all displays instead of just one
--so to get around this the name must be converted into an integer
--the names are in the form \\.\DISPLAY# starting from 1, while the integers start from 0
function findDisplayNumber()
    local name = mp.get_property('display-names')
    msg.verbose( 'display list: ' .. name)

    --if a comma is in the list the mpv window is on mutiple displays
    name1 = name:find(',')
    if (name1 == nil) then
        name = name
    else
        msg.verbose( 'found comma in display list at pos ' .. tostring(name1) .. ', will use the first display')

        --the display-fps property always refers to the first display in the display list
        --so we must extract the first name from the list
        name = string.sub(name, 0, name1 - 1)
    end

    msg.verbose( 'display name = ' .. name)
    var.dname = name

    --the last character in the name will always be the display number
    --we extract the integer and subtract by 1, as nircmd starts from 0
    local number = string.sub(name, -1)
    number = tonumber(number)
    number = number - 1

    var.dnumber = number
    msg.verbose( 'display number = ' .. number)

end

--chooses a width and height to switch the display to based on the resolution of the video
function getModifiedWidthHeight(width, height)

    --if UHD adaptive is disabled then it doesn't matter what the video resolution is it'll just use the current resolution
    if (options.UHD_adaptive == false) then
        height = var.original_height
        width = var.original_width
        goto functionend
    end
    --sets the monitor to 2160p if an UHD video is played, otherwise set to the default
    if (height < 1440) then
        height = var.original_height
        width = var.original_width
    else
        height = 2160
        width = 3840
    end

    ::functionend::
    msg.verbose( "setting display to: " .. width .. "x" .. height)
    return width, height
end

--toggles between using estimated and specified fps
--does so by modifying the script-opt list and reloading options
function toggleFpsType()
    local script_opts = mp.get_property("options/script-opts")
    
    if (string.find(script_opts, "changerefresh%-estimated_fps=") == nil) then
        msg.verbose( 'toggling estimated fps - no script-opt found adding option')
        script_opts = script_opts .. ",changerefresh-estimated_fps=no"
    end

    if (options.estimated_fps == true) then
        script_opts = script_opts:gsub("changerefresh%-estimated_fps=yes", "changerefresh%-estimated_fps=no")

        mp.commandv("show-text", "[Change-Refresh] now using container fps")
        msg.info( "now using container fps")
    else
        script_opts = script_opts:gsub("changerefresh%-estimated_fps=no", "changerefresh%-estimated_fps=yes")

        mp.commandv("show-text", "[Change-Refresh] now using estimated fps")
        msg.info( "now using estimated fps")
    end
    
    --the script is observing the scipt-opts property, so it will automatically update options after this line is run
    mp.set_property("options/script-opts", script_opts)
end

--picks which whitelisted rate to switch the monitor to
function findValidRate(rate)
    msg.verbose('searching for closest valid rate to ' .. rate)
    local closestRate
    rate = tonumber(rate)

    --picks either the same fps in the whitelist, or the next highest
    --if none of the whitelisted rates are higher, then it uses the highest
    for i = 1, #var.rateList, 1 do
        closestRate = var.rateList[i]
        msg.debug('comparing ' .. closestRate .. ' to ' .. rate)
        if (closestRate >= rate) then
            break
        end
    end
    msg.verbose('closest rate is ' .. closestRate)
    return closestRate
end

--executes commands to switch monior to video refreshrate
function matchVideo()
    --if the change is executed on a different monitor to the previous, and the previous monitor has not been been reverted
    --then revert the previous changes before changing the new monitor
    if ((var.beenReverted == false) and (var.dname ~= mp.get_property('display-names'))) then
        revertRefresh()
    end

    --finds and records the display name
    findDisplayNumber()

    --if beenReverted=true, then the current display settings may not be saved
    if (var.beenReverted == true) then
        --saves the actual resolution only if option set, otherwise uses the defaults
        if options.detect_monitor_resolution then
            var.original_width, var.original_height = getDisplayResolution()
        end

        var.original_fps = math.floor(mp.get_property_number('display-fps'))
        msg.verbose( 'saving original fps: ' .. var.original_fps)
    end

    --records video properties
    var.new_width = mp.get_property_number('dwidth')
    var.new_height = mp.get_property_number('dheight')
    msg.verbose( "video resolution = " .. tostring(var.new_width) .. "x" .. tostring(var.new_height))

    --saves either the estimated or specified fps of the video
    if (options.estimated_fps == true) then
        var.new_fps = mp.get_property_number('estimated-vf-fps')
    else
        var.new_fps = mp.get_property_number('container-fps')
    end
    
    --Floor is used because 23fps video has an actual framerate of ~23.9, this occurs across many video rates
    var.new_fps = math.floor(var.new_fps)
    var.new_width, var.new_height = getModifiedWidthHeight(var.new_width, var.new_height)

    --picks which whitelisted rate to switch the monitor to based on the video rate
    local rate = findValidRate(var.new_fps)

    --if the user has set a custom display rate for the video rate, then rate is changed to the new one
    msg.verbose('saved display rate for ' .. rate .. ' is ' .. var.rates[rate])
    rate = var.rates[rate]

    changeRefresh(var.new_width, var.new_height, rate)
end

--reverts the monitor to its original refresh rate
function revertRefresh()
    if (var.beenReverted == false) then
        msg.verbose( "reverting refresh rate")

        local rate = findValidRate(var.original_fps)
        changeRefresh(var.original_width, var.original_height, rate)
        var.beenReverted = true
    else
        msg.verbose( "aborting reversion, display has not been changed")
    end
end

--sets the current resolution and refresh as the default to use upon reversion
function setDefault()
    var.original_width, var.original_height = getDisplayResolution()
    var.original_fps = math.floor(mp.get_property_number('display-fps'))

    var.beenReverted = true

    --logging change to OSD & the console
    msg.info( 'set ' .. var.original_width .. "x" .. var.original_height .. " " .. var.original_fps .. "Hz as defaut display rate")
    mp.commandv('show-text', 'Change-Refresh: set ' .. var.original_width .. "x" .. var.original_height .. " " .. var.original_fps .. "Hz as defaut display rate")
end

--function for script message custom changes
function customChange(width, height, rate)
    findDisplayNumber()
    changeRefresh(width, height, rate)
end

--runs the script automatically on startup if option is enabled
function autoChange()
    if options.auto then
        --waits until some of the required properties have been loaded before running
        while mp.get_property_number('time-pos') < 0.5 do end

        msg.verbose('automatically changing refresh')
        matchVideo()
    end
end

updateOptions()

--key tries to changeRefresh current display to match video fps
mp.add_key_binding("f10", "change_refresh_rate", matchVideo)

--key reverts monitor to original refreshrate
mp.add_key_binding("Ctrl+f10", "revert_refresh_rate", revertRefresh)

--ket to switch between using estimated and specified fps property
mp.add_key_binding("", "toggle_fps_type", toggleFpsType)

--key to set the current resolution and refresh rate as the default
mp.add_key_binding("", "set_default_refresh_rate", setDefault)

--sends a command to switch to the specified display rate
--syntax is: script-message set-display-rate [width] [height] [fps]
mp.register_script_message("set-display-rate", customChange)

--updates options from script-opts whenever script-opts changes
mp.observe_property("options/script-opts", nil, updateOptions)

--runs the script automatically on startup if option is enabled
mp.register_event('file-loaded', autoChange)

--reverts refresh on mpv shutdown
mp.register_event("shutdown", revertRefresh)