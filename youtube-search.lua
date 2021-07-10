--[[
    This script allows users to search and open youtube results from within mpv.
    Available at: https://github.com/CogentRedTester/mpv-scripts

    Users can open the search page with Y, and use Y again to open a search.
    Alternatively, Ctrl+y can be used at any time to open a search.
    Esc can be used to close the page.
    Enter will open the selected item, Shift+Enter will append the item to the playlist.

    This script requires that my other scripts `scroll-list` and `user-input` be installed.
    scroll-list.lua and user-input-module.lua must be in the ~~/script-modules/ directory,
    while user-input.lua should be loaded by mpv normally.

    https://github.com/CogentRedTester/mpv-scroll-list
    https://github.com/CogentRedTester/mpv-user-input

    This script also requires a youtube API key to be entered.
    The API key must be passed to the `API_key` script-opt.
    A personal API key is free and can be created from:
    https://console.developers.google.com/apis/api/youtube.googleapis.com/

    The script also requires that curl be in the system path.
]]--

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"
local opts = require "mp.options"

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"}) .. package.path
local ui = require "user-input-module"
local list = require "scroll-list"

list.header = "Youtube Search Results\\N-----------------------------"
list.num_entries = 18
list.list_style = [[{\fs10}\N{\q2\fs25\c&Hffffff&}]]

local o = {
    API_key = "",
    num_results = 40
}

opts.read_options(o)

local ass_escape = list.ass_escape

--encodes a string so that it uses url percent encoding
--this function is based on code taken from here: https://rosettacode.org/wiki/URL_encoding#Lua
local function encode_string(str)
    if type(str) ~= "string" then return str end
	local output, t = str:gsub("[^%w]", function(char)
        return string.format("%%%X",string.byte(char))
    end)
	return output
end

--convert HTML character codes to the correct characters
local function html_decode(str)
    if type(str) ~= "string" then return str end

    return str:gsub("&(#?)(%w-);", function(is_ascii, code)
        if is_ascii == "#" then return string.char(tonumber(code)) end
        if code == "amp" then return "&" end
        if code == "quot" then return '"' end
        if code == "apos" then return "'" end
        if code == "lt" then return "<" end
        if code == "gt" then return ">" end
        return nil
    end)
end

--sends an API request
local function send_request(type, queries)
    local url = "https://www.googleapis.com/youtube/v3/"..type

    url = url.."?key="..o.API_key

    for key, value in pairs(queries) do
        msg.verbose(value, encode_string(value))
        url = url.."&"..key.."="..encode_string(value)
    end

    msg.debug(url)
    local request = mp.command_native({
        name = "subprocess",
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
        args = {"curl", url}
    })

    local response = utils.parse_json(request.stdout)
    msg.trace(utils.to_string(response))
    if request.status ~= 0 then msg.error(request.stderr) ; return nil end

    if not response.items then return msg.warn("Search did not return a results list") end

    --decodes the HTML character codes in the result titles
    for _, item in ipairs(response.items) do
        item.snippet.title = html_decode(item.snippet.title)
    end

    return response
end

local function insert_video(item)
    list:insert({
        ass = ("%s   {\\c&aaaaaa&}%s"):format(ass_escape(item.snippet.title), ass_escape(item.snippet.channelTitle)),
        url = "https://www.youtube.com/watch?v="..item.id.videoId
    })
end

local function insert_playlist(item)
    list:insert({
        ass = ("🖿 %s   {\\c&aaaaaa&}%s"):format(ass_escape(item.snippet.title), ass_escape(item.snippet.channelTitle)),
        url = "https://www.youtube.com/playlist?list="..item.id.playlistId
    })
end

local function insert_channel(item)
    list:insert({
        ass = ("👤 %s"):format(ass_escape(item.snippet.title)),
        url = "https://www.youtube.com/channel/"..item.id.channelId
    })
end

local function reset_list()
    list.selected = 1
    list:clear()
end

local function search(query)
    local response = send_request("search", {
        q = query,
        part = "id,snippet",
        maxResults = o.num_results
    })

    if not response then return end
    reset_list()

    for _, item in ipairs(response.items) do
        if item.id.kind == "youtube#video" then
            insert_video(item)
        elseif item.id.kind == "youtube#playlist" then
            insert_playlist(item)
        elseif item.id.kind == "youtube#channel" then
            insert_channel(item)
        end
    end
    list.header = "Youtube Search: "..ass_escape(query).."\\N-------------------------------------------------"
    list:update()
    list:open()
end

local function play_result(flag)
    if not list[list.selected] then return end
    if flag == "new_window" then mp.commandv("run", "mpv", list[list.selected].url) ; return end

    mp.commandv("loadfile", list[list.selected].url, flag)
    if flag == "replace" then list:close() end
end

table.insert(list.keybinds, {"ENTER", "play", function() play_result("replace") end, {}})
table.insert(list.keybinds, {"Shift+ENTER", "play_append", function() play_result("append-play") end, {}})
table.insert(list.keybinds, {"Ctrl+ENTER", "play_new_window", function() play_result("new_window") end, {}})

local function open_search_input()
    ui.get_user_input(function(input)
        if not input then return end
        search( input )
    end, { request_text = "Enter Query:" })
end

mp.add_key_binding("Ctrl+y", "yt", open_search_input)

mp.add_key_binding("Y", "youtube-search", function()
    if not list.hidden then open_search_input()
    else
        list:open()
        if #list.list == 0 then open_search_input() end
    end
end)
