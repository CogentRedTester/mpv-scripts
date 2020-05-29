--[[
    This script allows you to search for commands and have matching entries display on the OSD.
    The search is case insensitive, and searches the command name.
    The script sends the filter directly to a lua string match function, so you can use patterns to get more complex filtering

    The command is: script-message search-commands

    One the command is sent the console will open with a pre-entered search command, simply add a query string as the first argument.
    Once the results page is displayed it can be dismissed with esc
]]--

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local ov = mp.create_osd_overlay("ass-events")
ov.hidden = true

function close_overlay()
    ov.data = ""
    ov.hidden = true
    ov:update()
    mp.remove_key_binding("search_commands_key/close_overlay")
end

function fix_chars(str)
    str = tostring(str)
    str = str:gsub('{', "\\{")
    str = str:gsub('}', "\\}")
    return str
end

function add_result(cmd, args)
    cmd = fix_chars(cmd)
    args = fix_chars(args)

    ov.data = ov.data .. "\n" .. "{\\c&Hffff00>&\\fs20}" .. cmd .. "{\\c&H00cccc>&}" .. "      args: " .. "{\\fs15}" .. args .. "\\N \\N"
end

function search_keys(keyword)
    commands = mp.get_property_native('command-list')

    keyword = keyword:lower()

    ov.data = "{\\c&H00ccff>&\\fs40\b900\\q2}" ..  "Search results for '" .. keyword .. "'\
    {\\c&00ccff>&\\fs30\b100}-------------------------------------------------------"

    for i,command in ipairs(commands) do
        if
        command.name:lower():find(keyword)
        then
            local cmd = command.name
            add_result(cmd, utils.to_string(command.args))
        end
    end

    ov.hidden = false
    ov:update()
    mp.add_forced_key_binding("esc", "search_commands_key/close_overlay", close_overlay)
end

mp.register_script_message('search_commands/search', function(keyword)
    if keyword == nil then
        msg.warn('no input given for search')
        return
    end
    mp.command("script-binding console/_console_1")
    search_keys(keyword)
end)

mp.register_script_message('search-commands', function()
    mp.commandv('script-message-to', 'console', 'type', 'script-message search_commands/search ')
end)