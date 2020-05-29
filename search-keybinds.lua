--[[
    This script allows you to search for keybinds and have matching entries display on the OSD.
    The search is case insensitive, and searches the key name, the command, the input section, and any comments.
    The script sends the filter directly to a lua string match function, so you can use patterns to get more complex filtering

    The command is: script-binding search-keybinds

    One the command is sent the console will open with a pre-entered search command, simply add a query string as the first argument.
    Once the results page is displayed it can be dismissed with esc
]]--

local mp = require 'mp'
local msg = require 'mp.msg'
local opt = require 'mp.options'

local o = {
    ass_header = "{\\c&H00ccff>&\\fs40\b900\\q2}",
    ass_underline = "{\\c&00ccff>&\\fs30\b100}",
    ass_allresults = "{\\fs20\\q2}",
    ass_key = "{\\c&Hffccff>&}",
    ass_section = "{\\c&H00cccc>&}",
    ass_cmd = "{\\c&Hffff00>&}",
    ass_comment = "{\\c&H33ff66>&}"
}

opt.read_options(o, "search_keybinds")

local ov = mp.create_osd_overlay("ass-events")
ov.hidden = true

function close_overlay()
    ov.data = ""
    ov.hidden = true
    ov:update()
    mp.remove_key_binding("search_keybinds_key/close_overlay")
end

function fix_chars(str)
    str = tostring(str)
    str = str:gsub('{', "\\{")
    str = str:gsub('}', "\\}")
    return str
end

function add_result(key, section, cmd, comment)
    msg.debug("key: " .. key .. " section: " .. section .. " cmd: " .. cmd .. " comment: " .. comment)
    key = fix_chars(key)
    section = fix_chars(section)
    cmd = fix_chars(cmd)
    comment = fix_chars(comment)

    msg.verbose("key: " .. key .. " section: " .. section .. " cmd: " .. cmd .. " comment: " .. comment)
    ov.data = ov.data .. "\n" .. o.ass_allresults .. o.ass_key .. key .. o.ass_section .. section .. o.ass_cmd .. cmd .. o.ass_comment .. comment
end

function search_keys(keyword)
    local keys = mp.get_property_native('input-bindings')

    keyword = keyword:lower()

    ov.data = o.ass_header ..  "Search results for '" .. keyword .. "'\
    "..o.ass_underline.."-------------------------------------------------------"

    for _,keybind in ipairs(keys) do
        if
        keybind.key:lower():find(keyword)
        or keybind.cmd:lower():find(keyword)
        or (keybind.comment ~= nil and keybind.comment:lower():find(keyword))
        or (keybind.section:lower():find(keyword))
        then
            local key = keybind.key
            local section = ""
            local cmd = ""
            local comment = ""

            if keybind.section ~= nil and keybind.section ~= "default" then
                section = "  (" .. keybind.section .. ")"
            end

            local num_spaces = 20 - (key:len() + section:len())
            if num_spaces < 4 then num_spaces = 4 end
            cmd = string.rep(" ", num_spaces) .. keybind.cmd

            if keybind.comment ~= nil then
                num_spaces = 45 - keybind.cmd:len()
                if num_spaces < 4 then num_spaces = 4 end
                comment = string.rep(" ", num_spaces) .. "#" .. keybind.comment
            end

            add_result(key, section, cmd, comment)
        end
    end

    ov.hidden = false
    ov:update()
    mp.add_forced_key_binding("esc", "search_keybinds_key/close_overlay", close_overlay)
end

mp.register_script_message('search_keybinds/search', function(keyword)
    if keyword == nil then
        msg.warn('no input given for search')
        return
    end
    mp.command("script-binding console/_console_1")
    search_keys(keyword)
end)

mp.add_key_binding('f12','search-keybinds', function()
    mp.commandv('script-message-to', 'console', 'type', 'script-message search_keybinds/search ')
end)