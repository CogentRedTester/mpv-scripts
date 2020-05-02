local ov = mp.create_osd_overlay("ass-events")

mp.enable_messages('error')
mp.register_event('log-message', function(log)
    message = "{\\c&H0000AA>&}[" .. log.prefix .. "] " .. log.text
    ov.data = ov.data .. message
    ov:update()

    mp.add_timeout(4, function ()
        local endln = ov.data:find('\n') + 1
        ov.data = ov.data:sub(endln)
        ov:update()
    end)
end)