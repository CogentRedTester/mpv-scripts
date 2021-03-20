--[[
    A script to allow users to define commands which will query mpv-user-input for values.
    Available at: https://github.com/CogentRedTester/mpv-scripts

    The syntax is:
        script-message input-command [command string] [arg1 options] [arg2 options] ...

    Some examples:
        script-message input-command "loadfile %1" "encapsulate=yes"
        script-message input-command "seek %1 %2" "" "default=absolute"
        script-message input-command "screenshot-to-file %1" "encapsulate=yes|default=${screenshot-directory:~/Pictures/Screenshots}/${filename/no-ext}.png"

    This is very much still a work in progress, some of the options above may not work properly
]]

local mp = require "mp"
local utils = require "mp.utils"

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"}) .. package.path
local input = require "user-input-module"

local function substitute_arg(command, arg, text, opts)

    return command:gsub( "%%%%*"..arg, function(str)
        local prepended_hashes = str:match("^%%+"):len()
        local number = str:sub(prepended_hashes+1)
        if number == "" then return false end

        str = str:sub(1, math.floor(prepended_hashes/2))
        if prepended_hashes % 2 == 0 then return str..number end

        if opts.encapsulate then text = string.format("%q", text) end
        return str..text
    end)
end

local commands = {}

local function main(command, ...)
    local num_args, opts

    if commands[command] then
        num_args = commands[command].num_args
        opts = commands[command].opts

    else
        commands[command] = {}
        opts = {...}

        for i, opt in ipairs(opts) do
            opts[i] = {}
            for str in opt:gmatch("[^|]+") do
                local key = str:match("^[^=]+")
                opts[i][key] = str:sub(key:len()+2)
            end
        end
        commands[command].opts = opts

        local args = {}
        for str in command:gmatch("%%%%*[%d]*") do
            local prepended_hashes = str:match("^%%+"):len()
            local number = str:sub(prepended_hashes+1)
            if number ~= "" and prepended_hashes % 2 == 1 then
                local num = tonumber(number)
                args[num] = true
            end
        end
        num_args = #args
        commands[command].num_args = num_args
    end

    local command_copy = command
    for i = 1, num_args, 1 do
        input.get_user_input(function(text)
            if not text then return end
            command = substitute_arg(command, i, text, opts[i])

            if i == num_args then mp.command(command) end
        end, {
            id = command..'/'..tostring(i),
            queueable = true,
            request_text = "Enter argument "..i.." for command: "..command_copy,
            default_input = opts[i].default or ""
        })
    end
end

mp.register_script_message("input-command", main)
