--[[
    This script allows you to search for commands and have matching entries display on the OSD.
    The search is case insensitive, and searches the command name.
    The script sends the filter directly to a lua string match function, so you can use patterns to get more complex filtering

    When the search results are up you can auto load the first 9 commands in console.lua by using the number keys

    The command is: script-binding search-commands

    One the command is sent the console will open with a pre-entered search command, simply add a query string as the first argument.
    Once the results page is displayed it can be dismissed with esc

    Green commands are classified as optional, while cyan are not. However, this does not always seem to be accurate.
]]--

local mp = require 'mp'
local opt = require 'mp.options'
local msg = require 'mp.msg'

local o = {
    ass_header = "{\\c&H00ccff>&\\fs40\b900\\q2}",
    ass_underline = "{\\c&00ccff>&\\fs30\b100}",
    ass_cmd = "{\\c&Hffccff>\\fs20}",
    ass_outerbrackets = "{\\fs20\\c&H00cccc>&}",
    ass_args = "{\\fs20\\c&H33ff66>&}",
    ass_optargs = "{\fs20\\c&Hffff00>&}",
    ass_argtype = "{\\c&H00cccc>&}{\\fs12}"
}

opt.read_options(o, "search_commands")

local ov = mp.create_osd_overlay("ass-events")
ov.hidden = true

local keys = {
    "search_commands_key/1",
    "search_commands_key/2",
    "search_commands_key/3",
    "search_commands_key/4",
    "search_commands_key/5",
    "search_commands_key/6",
    "search_commands_key/7",
    "search_commands_key/8",
    "search_commands_key/9",
    "search_commands_key/close_overlay"
}

function close_overlay()
    ov.data = ""
    ov.hidden = true
    ov:update()

    for _,key in ipairs(keys) do
        mp.remove_key_binding(key)
    end
end

function fix_chars(str)
    str = tostring(str)
    str = str:gsub('{', "\\{")
    str = str:gsub('}', "\\}")
    return str
end

--adds the results to the list
function add_result(cmd, args, num_entry)
    --adds 1-9 keybinds for the first 9 entries
    if num_entry < 10 then
        mp.add_forced_key_binding(tostring(num_entry), keys[num_entry], function()
            mp.commandv('script-message-to', 'console', 'type', cmd.." ")
            close_overlay()
        end)
    end

    cmd = fix_chars(cmd)

    ov.data = ov.data .. "\n" .. o.ass_cmd .. cmd .. "        "..o.ass_outerbrackets.."("
    for _,arg in ipairs(args) do
        if arg.optional then
            ov.data = ov.data .. o.ass_optargs
        else
            ov.data = ov.data .. o.ass_args
        end

        ov.data = ov.data .. " " .. arg.name .. o.ass_argtype.." ("..arg.type.."), "
    end
    ov.data = ov.data .. o.ass_outerbrackets ..") \\N"
end

function search_keys(keyword)
    commands = mp.get_property_native('command-list')

    keyword = keyword:lower()

    ov.data = o.ass_header..  "Search results for '" .. keyword .. "'\
    "..o.ass_underline.."-------------------------------------------------------"

    local num_entries = 0
    for i,command in ipairs(commands) do
        if
        command.name:lower():find(keyword)
        then
            num_entries = num_entries + 1
            local cmd = command.name
            add_result(cmd, command.args, num_entries)
        end
    end

    ov.hidden = false
    ov:update()
    mp.add_forced_key_binding("esc", keys[10], close_overlay)
end

mp.register_script_message('search_commands/search', function(keyword)
    if keyword == nil then
        msg.warn('no input given for search')
        return
    end
    mp.command("script-binding console/_console_1")
    search_keys(keyword)
end)

mp.add_key_binding("Ctrl+f12",'search-commands', function()
    mp.commandv('script-message-to', 'console', 'type', 'script-message search_commands/search ')
end)