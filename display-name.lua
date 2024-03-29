--[[
    A simple script designed for Windows that saves the name of the monitor that mpv is using into
    the `display_name` field of the `user-data` property.
    Only works with mpv v0.36+. See repo history for older versions that used shared-script-properties.
    
    This means that one can use conditional auto profiles with the name of the monitor:

    [PC]
    profile-cond= 'SAMSUNG' or user_data.display_name ~= 'SAMSUNG'
    script-opts-append=changerefresh-auto=no

    [TV]
    profile-cond= user_data.display_name == 'SAMSUNG'
    script-opts-append=changerefresh-auto=yes

    Run `mpv --idle=once --script-opts=display_names=yes` to get a list of names for the current displays.

    This is necessary on windows because the default display names that mpv uses
    are in the form \\.\DISPLAY#, which are completely useless for setting persistent profiles
    as the numbers can change between boots or display configurations.

    This script requires that MultiMonitorTool.exe (https://www.nirsoft.net/utils/multi_monitor_tool.html)
    be available in the system path.

    Available at: https://github.com/CogentRedTester/mpv-scripts/blob/master/display-name.lua
]]

local mp = require 'mp'
local msg = require 'mp.msg'
local utils = require 'mp.utils'

-- this platform test was taken from mpv's console.lua
local PLATFORM_WINDOWS = mp.get_property_native('options/vo-mmcss-profile', mp) ~= mp

-- a table of displays, uses the ID names returned by mpv's display-names property
local displays = {}

-- gets the path of a temporary file that can be used by the script
local function get_temp_file_name()
    local file = os.tmpname()
    if not PLATFORM_WINDOWS then return file
    else return utils.join_path(mp.command_native({"expand-path", "~/AppData/Local/Temp"}), file) end
end

-- creates an iterator for cells in a csv row
local function csv_iter(str)
    -- cleans up cells that are wrappen in brackets
    str = str:gsub('".-"', function(substr) return substr:gsub(', ', 'x'):gsub(',', ' '):sub(2, -2) end)
    return string.gmatch(str, '[^,\n\r]+')
end

-- loads the display information into the displays table
local function load_display_info()
    local name = get_temp_file_name()

    local cmd = mp.command_native({
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        args = {'MultiMonitorTool.exe', '/scomma', name}
    })

    mp.register_event('shutdown', function()
        msg.debug('deleting', name)
        os.remove(name)
    end)

    if cmd.status ~= 0 then
        msg.error('failed to run MultiMonitorTool.exe. Status code:', cmd.status)
        return false
    end

    local f = io.open(name, "r")
    if not f then return msg.error('failed to open file ', name) end
    local header_str = f:read("*l")
    local headers = {}

    for header in csv_iter(header_str) do
        table.insert(headers, header)
    end

    for row in f:lines() do
        local i = 1
        local display = {}
        for cell in csv_iter(row) do
            -- print(headers[i] or '', cell)
            display[headers[i]] = cell
            i = i + 1
        end

        msg.debug(utils.to_string(display))
        if not display.Name then return msg.error('display did not return a name') end
        displays[display.Name] = display
    end
end

mp.observe_property('display-names', 'native', function(_, display_names)
    if not display_names then return end

    local display = display_names[1]
    if not display then
        mp.set_property('user-data/display_name', '')
        return
    end

    -- this script should really only be used on windows, but just in case I'll leave this here
    if not PLATFORM_WINDOWS then
        mp.set_property('user-data/display_name', display)
        return
    end

    if not displays[display] then
        load_display_info()
    end

    local name = 'unknown'
    if displays and displays[display] then name = displays[display]['Monitor Name'] or name end
    mp.set_property('user-data/display_name', name)
end)

mp.set_property('user-data/display_name', '')

-- prints the names of the current displays to the console
if mp.get_opt('display_names') then
    load_display_info()
    for name, display in pairs(displays) do
        msg.info(name, display['Monitor Name'])
    end
end
