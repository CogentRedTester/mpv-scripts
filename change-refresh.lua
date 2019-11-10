utils = require 'mp.utils'

videoProperties = {
    ["height"] = "",
    ["width"] = "",
    ["rate"] = "",
}

monitorProperties = {
    ["name"]   = "0",
    ["width"]    = "1920",
    ["height"]   = "1080",
    ["bdepth"]    = "32",
    ["rate"]     = "60",
    ["beenReverted"] = true
}

--calls nircmd to change the display resolution and rate
function change(monitor, width, height, rate)
    mp.set_property("pause", "yes")
    local time = mp.get_time()
    print("changing " .. monitor .. " to " .. width .. "x" .. height .. " " .. rate .. "Hz")
    utils.subprocess({
        ["cancellable"] = false,
        ["args"] = {
            [1] = "nircmd",
            [2] = "setdisplay",
            [3] = "monitor:" .. monitor,
            [4] = width,
            [5] = height,
            [6] = "32",
            [7] = rate
        }
    })

    --waits 3 seconds then unpauses the videoPropertie
    --prevents AV desyncs
    while (mp.get_time() - time < 3)
    do
    end
    mp.set_property("pause", "no")
end

--records the properties of the currently playing video
function recordVideoProperties()
    videoProperties.width = mp.get_property_number('width')
    videoProperties.height = mp.get_property_number('height')
    videoProperties.rate = mp.get_property_number('estimated-vf-fps')
end

--records the original monitor properties
function recordMonitorProperties()
    monitorProperties.name = mp.get_property('display-names')
    monitorProperties.rate = mp.get_property_number('display-fps')
end

--modifies the properties of the video to work with nircmd
function modifyVideoProperties()
    --Floor is used because 23fps video has an actual frate of ~23.9
    videoProperties.rate = math.floor(videoProperties.rate)

    --high monitor tv framerates seem to vary between being above or below, so proper rounding is used
    if (monitorProperties.rate % 1 >= 0.5) then
        monitorProperties.rate = math.ceil(monitorProperties.rate)
    else
        monitorProperties.rate = math.floor(monitorProperties.rate)
    end

    --sets the monitor to 2160p if an UHD video is player, otherwise set to 1080p
    if (videoProperties.height < 1440) then
        videoProperties.height = 1080
        videoProperties.width = 1920
    else
        videoProperties.height = 2160
        videoProperties.width = 3840
    end
end

--reverts the monitor to its original refresh rate
function revertRefresh()
    change(monitorProperties.name, monitorProperties.width, monitorProperties.height, tostring(monitorProperties.rate))
    monitorProperties.beenReverted = true
end

--executes commands to switch monior to video refreshrate
function matchVideo()
    --if the change is executed on a different monitor to the previous, and the previous monitor has not been been reverted
    --then revert the previous changes before changing the new monitor
    if ((monitorProperties.beenReverted == false) and (monitorProperties.name == mp.get_property('display-names'))) then
        revertRefresh()
    end

    --records the current monitor prperties and video properties
    recordMonitorProperties()
    recordVideoProperties()

    modifyVideoProperties()

    change(monitorProperties.name, tostring(videoProperties.width), tostring(videoProperties.height), tostring(videoProperties.rate))
    monitorProperties.beenReverted = false
end

--key tries to change current display to match video fps
mp.add_key_binding('f10', matchVideo)

--key reverts monitor to original refreshrate
mp.add_key_binding('f11', revertRefresh)

--reverts refresh on mpv shutdown
mp.register_event("shutdown", revertRefresh)