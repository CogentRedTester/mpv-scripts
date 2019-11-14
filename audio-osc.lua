

mp.register_event("file-loaded", function()
    local hasvid = mp.get_property_osd("video") ~= "no"
    hasvid = false
    mp.commandv("script-message", "osc-visibility", (hasvid and "auto" or "always"), "no-osd")
    -- remove the next line if you don't want to affect the osd-bar config
    mp.commandv("set", "options/osd-bar", (hasvid and "yes" or "no"))

    print(mp.get_property("options/script-opts"))

    mp.commandv("set", "options/osc-boxvideo", "yes")
end)