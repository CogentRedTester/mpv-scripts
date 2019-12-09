function applyProfile (profile, message)
    
    if message == nil then
        mp.commandv("show-text", "applying profile: " .. profile)
    else
        mp.commandv("show-text", message)
    end

    print("pause")
    isPaused = mp.get_property_bool('pause')
    mp.set_property_bool('pause', true)

    mp.commandv("apply-profile", profile)
    --mp.set_property_bool('pause', isPaused)
end

mp.register_script_message("apply-profile-pause", applyProfile)