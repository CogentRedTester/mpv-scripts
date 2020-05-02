local mp = require 'mp'
local opt = require 'mp.options'

local o = {
    --add a blacklist for error messages to not print to the OSD
    --can be either the command prefix, a.k.a "[ffmpeg]"
    --or the error text, but not both
    blacklist = ""
}

opt.read_options(o, 'show_errors')

--splits the string into a table on the semicolons
local blacklist = {}
for str in string.gmatch(o.blacklist, "([^;]+)") do
        str = str
        blacklist[str] = true
end

local ov = mp.create_osd_overlay("ass-events")

mp.enable_messages('error')
mp.register_event('log-message', function(log)
    if blacklist[log.text:sub(1, -2)] or blacklist[log.prefix] then return end

    message = "{\\c&H0000AA>&}[" .. log.prefix .. "] " .. log.text
    ov.data = ov.data .. message
    ov:update()

    mp.add_timeout(4, function ()
        local endln = ov.data:find('\n') + 1
        ov.data = ov.data:sub(endln)
        ov:update()
    end)
end)