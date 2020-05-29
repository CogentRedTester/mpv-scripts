--[[
    This script allows you to search for keybinds, properties, options and commands and have matching entries display on the OSD.
    The search is case insensitive, and the script sends the filter directly to a lua string match function,
    so you can use patterns to get more complex filtering.

    The keybind page searches and displays the key, command, section, and any comments.
    The command page searches just the command name, but also shows information about arguments.
    The properties page will search just the property name, but will also show contents of the property
    The options page will search the name and option choices, it shows default values, choices, and ranges
    
    The search page will remain open until told to close. This key is esc.

    The keybind and command pages have a jumplist implementation, while on the search page you can press the number keys, 1-9,
    to select the entry at that location. On the keybinds page it runs the command without exitting the page,
    on the commands page it exits the page and loads the command up into console.lua.

    The default commands are:
        f12 script-binding search-keybinds
        Ctrl+f12 script-binding search-commands
        Shift+f12 script-binding search-properties
        Alt+f12 script-binding search-options

    Once the command is sent the console will open with a pre-entered search command, simply add a query string as the first argument.
]]--

local mp = require 'mp'
local msg = require 'mp.msg'
local opt = require 'mp.options'

local o = {
    --enables the 1-9 jumplist for the search pages
    enable_jumplist = true,

    --there seems to be a significant performance hit from having lots of text off the screen
    max_list = 40,

    --both colour options
    ass_header = "{\\c&H00ccff>&\\fs40\\b500\\q2}",
    ass_underline = "{\\c&00ccff>&\\fs30\\b100}",

    --colours for keybind page
    ass_allkeybindresults = "{\\fs20\\q2}",
    ass_key = "{\\c&Hffccff>&}",
    ass_section = "{\\c&H00cccc>&}",
    ass_cmdkey = "{\\c&Hffff00>&}",
    ass_comment = "{\\c&H33ff66>&}",

    --colours for commands page
    ass_cmd = "{\\c&Hffccff>\\fs20}",
    ass_outerbrackets = "{\\fs20\\c&H00cccc>&}",
    ass_args = "{\\fs20\\c&H33ff66>&}",
    ass_optargs = "{\fs20\\c&Hffff00>&}",
    ass_argtype = "{\\c&H00cccc>&}{\\fs12}",

    --colours for property list
    ass_properties = "{\\c&Hffccff>\\fs20\\q2}",
    ass_propertycurrent = "{\\c&Hffff00>&}",

    --colours for options list
    ass_options = "{\\c&Hffccff>\\fs20}",
    ass_optionstype = "{\\c&H00cccc>&}{\\fs12}",
    ass_optionsdefault = "{\\c&H33ff66>&\\fs20}",

    --list of choices for choice options, ranges for numeric options
    ass_optionsspec = "{\\c&Hffff00>&}",
}

opt.read_options(o, "search_page")

local ov = mp.create_osd_overlay("ass-events")
local osd_display = mp.get_property_number('osd-duration')
ov.hidden = true

local dynamic_keybindings = {
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

--removes keybinds
function remove_bindings()
    for _,key in ipairs(dynamic_keybindings) do
        mp.remove_key_binding(key)
    end
end

--closes the overlay and removes bindings
function close_overlay()
    ov.data = ""
    ov.hidden = true
    ov:update()
    remove_bindings()
end

function open_overlay()
    ov.hidden = false
    ov:update()
    mp.add_forced_key_binding("esc", dynamic_keybindings[10], close_overlay)
end

--replaces any characters that ass can't display normally
--currently this is just curly brackets
function fix_chars(str)
    str = tostring(str)
    str = str:gsub('{', "\\{")
    str = str:gsub('}', "\\}")
    return str
end

function create_keybind(num_entry, funct)
    if num_entry < 10 then
        mp.add_forced_key_binding(tostring(num_entry), dynamic_keybindings[num_entry], funct)
    end
end

--add results to the keybinds page
function add_result_keybind(key, section, cmd, comment, num_entries)
    
end

--loads the header for the search page
function load_header(keyword, name)
    if name == nil then name = "" end
    ov.data = o.ass_header .. "Search results for " .. name .. " '" .. keyword .. "'\
    "..o.ass_underline.."-------------------------------------------------------"
end

--search keybinds
function search_keys(keyword)
    local keys = mp.get_property_native('input-bindings')
    load_header(keyword, "key")

    local num_entries = 0
    for _,keybind in ipairs(keys) do
        if
        keybind.key:lower():find(keyword)
        or keybind.cmd:lower():find(keyword)
        or (keybind.comment ~= nil and keybind.comment:lower():find(keyword))
        or (keybind.section:lower():find(keyword))
        or keybind.key:lower():find(keyword:lower())
        or keybind.cmd:lower():find(keyword:lower())
        or (keybind.comment ~= nil and keybind.comment:lower():find(keyword:lower()))
        or (keybind.section:lower():find(keyword:lower()))
        then
            local key = keybind.key
            local section = ""
            local cmd = ""
            local comment = ""

            --add section string to entry
            if keybind.section ~= nil and keybind.section ~= "default" then
                section = "  (" .. keybind.section .. ")"
            end

            --add command to entry
            local num_spaces = 20 - (key:len() + section:len())
            if num_spaces < 4 then num_spaces = 4 end
            cmd = string.rep(" ", num_spaces) .. keybind.cmd

            --add comments to entry
            if keybind.comment ~= nil then
                num_spaces = 45 - keybind.cmd:len()
                if num_spaces < 4 then num_spaces = 4 end
                comment = string.rep(" ", num_spaces) .. "#" .. keybind.comment
            end

            num_entries = num_entries + 1

            --stops the loop if too many files are added
            if num_entries > o.max_list then break end

            --creates the entries
            create_keybind(num_entries, function()
                ov.hidden = true
                ov:update()
                mp.command(cmd)

                mp.add_timeout(osd_display/1000, function()
                    ov.hidden = false
                    ov:update()
                end)
            end)

            key = fix_chars(key)
            section = fix_chars(section)
            cmd = fix_chars(cmd)
            comment = fix_chars(comment)

            --appends the result to the list
            ov.data = ov.data .. "\n" .. o.ass_allkeybindresults .. o.ass_key .. key .. o.ass_section .. section .. o.ass_cmdkey .. cmd .. o.ass_comment .. comment
        end
    end

    open_overlay()
end

--search commands
function search_commands(keyword)
    commands = mp.get_property_native('command-list')
    load_header(keyword, "cmd")

    local num_entries = 0
    for _,command in ipairs(commands) do
        if
        command.name:lower():find(keyword)
        or command.name:lower():find(keyword:lower())
        then
            --creates dynamic keybinds jumplist for the commands
            num_entries = num_entries + 1

            --if the entries has gone above the max then stop adding more
            if num_entries > o.max_list then break end
            cmd = fix_chars(command.name)

            ov.data = ov.data .. "\n" .. o.ass_cmd .. cmd .. "        "..o.ass_outerbrackets.."("
            for _,arg in ipairs(command.args) do
                if arg.optional then
                    ov.data = ov.data .. o.ass_optargs
                else
                    ov.data = ov.data .. o.ass_args
                end
                ov.data = ov.data .. " " .. arg.name .. o.ass_argtype.." ("..arg.type.."), "
            end
            ov.data = ov.data .. o.ass_outerbrackets ..") \\N"
            create_keybind(num_entries, function()
                mp.commandv('script-message-to', 'console', 'type', cmd .. " ")
                close_overlay()
            end)
        end
    end

    open_overlay()
end

function search_options(keyword)
    local options = mp.get_property_native('options')
    load_header(keyword, "option")

    local num_entries = 0
    for _,option in ipairs(options) do
        if option:find(keyword)
        or option:find(keyword:lower())
        or mp.get_property('option-info/'..option..'/choices', ""):find(keyword)
        or mp.get_property('option-info/'..option..'/choices', ""):find(keyword:lower())
        then
            num_entries = num_entries + 1

            local type = mp.get_property('option-info/'..option..'/type', '')
            local option_type = "  (" .. type ..")"

            local whitespace = 80 - (option:len() + option_type:len())
            if whitespace < 4 then whitespace = 4 end
            local default = "#" ..  mp.get_property('option-info/'..option..'/default-value', "")
            if default == "#" then default = "" end
            local option_default = string.rep(" ", whitespace) .. default

            local options_spec = ""

            if type == "Choice" then
                options_spec = fix_chars("          [ " .. mp.get_property("option-info/"..option..'/choices', ""):gsub(",", " , ") .. ' ]')
            elseif type == "Integer"
            or type == "ByteSize"
            or type == "Float"
            or type == "Aspect"
            or type == "Double" then
                options_spec = fix_chars("          [ "..mp.get_property('option-info/'..option..'/min', "").."  -  ".. mp.get_property("option-info/"..option..'/max', "").." ]")
            end

            if num_entries > o.max_list then break end
            ov.data = ov.data .. "\n" .. o.ass_options .. option .. o.ass_optionstype .. option_type .. o.ass_optionsdefault .. option_default .. o.ass_optionsspec .. options_spec
        end
    end
    open_overlay()
end

function search_property(keyword)
    local properties = mp.get_property_native('property-list', {})
    load_header(keyword, "property")

    local num_entries = 0
    for _,property in ipairs(properties) do
        if property:find(keyword:lower()) then
            num_entries = num_entries + 1

            if num_entries > o.max_list then break end
            ov.data = ov.data .. "\n" .. o.ass_properties .. property .. "           " .. o.ass_propertycurrent .. fix_chars(mp.get_property(property, ""))
        end
    end
    open_overlay()
end

--recieves the input messages
mp.register_script_message('search_page/input', function(type, keyword)
    if keyword == nil then
        msg.error('no input given for search')
        return
    end

    local funct
    if type == "key$" then
        funct = search_keys
    elseif type == "cmd$" then
        funct = search_commands
    elseif type == "prop$" then
        funct = search_property
    elseif type == "opt$" then
        funct = search_options
    else
        msg.error("invalid type, must be either 'cmd' or 'key'")
        return
    end

    mp.command("script-binding console/_console_1")
    remove_bindings()
    funct(keyword)
end)

mp.add_key_binding('f12','search-keybinds', function()
    mp.commandv('script-message-to', 'console', 'type', 'script-message search_page/input key$ ')
end)

mp.add_key_binding("Ctrl+f12",'search-commands', function()
    mp.commandv('script-message-to', 'console', 'type', 'script-message search_page/input cmd$ ')
end)

mp.add_key_binding("Shift+f12", "search-properties", function()
    mp.commandv('script-message-to', 'console', 'type', 'script-message search_page/input prop$ ')
end)

mp.add_key_binding("Alt+f12", "search-options", function()
    mp.commandv('script-message-to', 'console', 'type', 'script-message search_page/input opt$ ')
end)