--[[
    This script allows users to set custom variables which can be used in commands and profiles.
    Availabe at: https://github.com/CogentRedTester/mpv-scripts

    variable names can consist of any combinations of: `a-z`,`A-Z`,`0-9` and `_`,
    variable values can be any string

    variables can be set using three different methods:

    1.  inside the ~~/script-opts/vars.conf file using the standard script syntax
    2.  by declaring a vars-[name] script-opt, this is the recommended method for setting vars within profiles
    3.  through the command: script-message set-var [name] [value]

    if the [value] argument of the command is left out then the variable will be reset to the value
    specified in the config file or removed.

    commands can be sent using: script-message var-command [cmd] [arg1] [arg2]
    or by placing the whole command into a string: script-message var-command !'cmd arg1 arg2'!

    inside these commands, any substring in the form %var_name% will be replaced with the value
    of the variable (if the var is set). Placinge extra `%` characters before the substring will
    escape the substitution.

    variables can be accessed for conditional auto-profiles through the `shared-script-properties` property:
    profile-cond=shared_script_properties.vars_[name] == "value"
]]--

local mp = require "mp"
local utils = require "mp.utils"
local msg = require "mp.msg"

local vars = {}
local config_vars = {}

--changes the given 
local function change_var(name, val)
    --if no value is provided then we reset the value to the inital value
    if not val then val = config_vars[name] end

    if val then msg.verbose("setting var", name, "to", '"'..val..'"')
    else msg.verbose("removing var", name) end

    --the values are saved to shared script properties so that other scripts like auto_profile can use them
    utils.shared_script_property_set("vars_"..name, val)
    vars[name] = val
end

--import variables from the config file
local function import_vars()
    local conffilename = "script-opts/vars.conf"
    local conffile = mp.find_config_file(conffilename)
    if not conffile then return end

    local file = io.open(conffile, "r")
    if not file then return end

    for line in file:lines() do
        if line:sub(#line) == "\r" then
            line = line:sub(1, #line - 1)
        end
        if line:sub(1,1) ~= "#" then
            local _, eqpos = line:find("^[%w_]+=")
            if eqpos then
                local key = line:sub(1, eqpos-1)
                local val = line:sub(eqpos+1)
                change_var(key, val)
            elseif line ~= "" then
                msg.warn("cannot parse line:", line)
            end
        end
    end

    for key, value in pairs(vars) do
        config_vars[key] = value
    end
end

import_vars()

mp.observe_property("options/script-opts", "native", function(_, opts)
    for key, value in pairs(opts) do
        if key:sub(1, 5) == "vars-" then
            local name = key:match("-([%w_]+)$")
            if not name then
                msg.error("variable name contains invalid characters - can only contain alphanumeric or '_' characters")
                mp.commandv("change-list", "script-opts", "remove", key)
                return
            end
            if vars[name] ~= value then change_var(name, value) end
        end
    end
end)

--substitute %var% for var value
--extra % before the initial % will escape the substitution
local function substitute_code(code)
    local prepended_hashes = code:match("^%%+"):len()
    local var = code:sub(prepended_hashes+1, -2)
    if not vars[var] then return false end

    code = code:sub(1, math.floor(prepended_hashes/2))..var
    if prepended_hashes % 2 == 0 then return code.."%" end

    return code:gsub(var, vars[var])
end

local function substitute_vars(t)
    for i, str in ipairs(t) do
        t[i] = str:gsub("%%%%*[%w_]*%%", substitute_code)
    end
end

local function var_command(...)
    local command = {...}
    substitute_vars(command)
    if #command == 1 then
        mp.command(command[1])
    else
        mp.command_native(command)
    end
end

mp.register_script_message("var-command", var_command)

--add some basic input handling around the change_var function
mp.register_script_message("set-var", function(name, value)
    if not name then msg.error("cannot set variable - no name given") ; return end
    if name:find("[^%w_]") then msg.error("variable name contains invalid characters - can only contain alphanumeric or '_' characters") ; return end
    change_var(name, value)
end)
