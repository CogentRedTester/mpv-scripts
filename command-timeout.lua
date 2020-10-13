--[[
    This script sends an input command, but only after the specified delay
    The last argument is the time in seconds before the command executes,
    the preceding arguments are the command in json array format

    example:
        script-message command-timeout ["show-text" , "hello" , "2000"] 2

    If the timeout is not given then it uses the global default set via script-opts
    The command string can have spaces at any point but before/after the square brackets.
    If the same timeout command is sent before the timer runs out, then the
    timer is reset without sending the command.

    available at: https://github.com/CogentRedTester/mpv-scripts
]]--

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'
local opt = require 'mp.options'

local o = {
    timeout = 5,
}
opt.read_options(o, 'command_timeout')

local timers = {}

mp.register_script_message('command-timeout', function(...)
    msg.verbose('recieved arguments: ' .. ...)
    local args = {...}
    if #args < 1 then
        msg.error('not enough arguments, script requires at least 1')
    end

    local str = ""
    for i = 1, #args do
        str = str .. " " .. args[i]
    end

    if timers[str] then
        msg.verbose('resetting time on timeout: ' .. str)
        timers[str]:kill()
        timers[str]:resume()
        return
    end

    local cmd, error, timeout = utils.parse_json(str, true)
    if timeout == "" then
        msg.verbose('did not recieve timeout, using default')
        timeout = o.timeout
    else
        timeout = tonumber(timeout)
    end
    if timeout == nil then
        msg.error('did not recieve vaid timeout')
        return
    end

    timers[str] = mp.add_timeout(timeout, function()
        msg.verbose('sending command: ' .. str)
        local def, error = mp.command_native(cmd, true)

        if def then
            msg.error('error sending command ' .. str)
            msg.error(error)
        end
    end)
end)