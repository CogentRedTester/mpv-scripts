--[[
    This script sends an input command, but only after the specified delay
    The first argument is the time in seconds before the command executes,
    the following argument if the command in json array format

    example:
        script-message command-timeout 2 ["show-text" , "hello" , "2000"]

    The timeout is mandatory. The command string can have spaces.
    If the same timeout command is sent before the timer runs out, then the
    timer is reset without sending the command.
]]--

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

local timers = {}

mp.register_script_message('command-timeout', function(...)
    msg.verbose('recieved arguments: ' .. ...)
    local args = {...}
    if #args < 2 then
        msg.error('not enough arguments, script requires at least 2')
    end
    local timeout = tonumber(args[1])

    if timeout == nil then
        msg.error('did not recieve a valid timeout')
    end

    local str = ""
    for i = 2, #args do
        str = str .. " " .. args[i]
    end

    if timers[str] == nil then
        local cmd = utils.parse_json(str)
        timers[str] = mp.add_timeout(timeout, function()
            msg.verbose('sending command: ' .. str)
            local def, error = mp.command_native(cmd, true)

            if def then
                msg.error('error sending command ' .. str)
                msg.error(error)
            end
        end)
    else
        timers[str]:kill()
        timers[str]:resume()
    end
end)