--[=====[
    An extremely basic script to allow people to send input command via profiles

    Cannot send the same command multiple times in a row

    syntax:
        single command:         ["command","arg1","arg2"]
        multiple commands:      [["command1","arg"],["command2","arg2"]]

        if you want to include spaces use %20
]=====]--

local o = {
    cmd = ""
}

local opt = require 'mp.options'
local utils = require 'mp.utils'

opt.read_options(o, 'profile_command', function()
    if o.cmd == "" then return end
    o.cmd = o.cmd:gsub("%%20", " ")
    local command = utils.parse_json(o.cmd)

    if command == nil then
        msg.error('invalid command syntax for ' .. o.cmd)
        return
    elseif type(command[1]) ~= "table" then
        local def, error = mp.command_native(command, true)
        if def then
            msg.error('Error occurred for command: ' .. utils.to_string(command))
        end
        return
    end

    for i,cmd in ipairs(command) do
        local def, error = mp.command_native(cmd, true)
        if def then
            msg.error('Error occurred for command: ' .. utils.to_string(cmd))
        end
    end
end)