function applyProfile (profile, message)
    
    if message == nil then
        mp.osd_message("applying profile: " .. profile)
    else
        mp.osd_message(message)
    end

    print("pause")
    isPaused = mp.get_property_bool('pause')
    mp.set_property_bool('pause', true)

    mp.commandv("apply-profile", profile)
    --mp.set_property_bool('pause', isPaused)
end

mp.register_script_message("apply-profile-pause", applyProfile)