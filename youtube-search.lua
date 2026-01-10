--[[
    This script allows users to search and open youtube results from within mpv using yt-dlp.
    Available at: https://github.com/CogentRedTester/mpv-scripts

    Users can open the search page with Y, and use Y again to open a search.
    Alternatively, Ctrl+y can be used at any time to open a search.
    Esc can be used to close the page.
    Enter will open the selected item, Shift+Enter will append the item to the playlist.

    This script requires that my other scripts `scroll-list` and `user-input` be installed.
    scroll-list.lua and user-input-module.lua must be in the ~~/script-modules/ directory,
    while user-input.lua should be loaded by mpv normally.

    yt-dlp must also be available in the system path

    https://github.com/CogentRedTester/mpv-scroll-list
    https://github.com/CogentRedTester/mpv-user-input
]]--

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"
local opts = require "mp.options"

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"}) .. package.path
local ui = require "user-input-module"
local list = require "scroll-list"

local o = {
    --number of search results to show in the list
    num_results = 40,

    --the url to send API calls to
    yt_dlp_path = "yt-dlp",

    --The search query to sent to yt-dlp. `%s` is substituted for the search query.
    search_query = "https://www.youtube.com/search?q=%s",

    frontend = "https://www.youtube.com",
}

opts.read_options(o)

--ensure the URL options are properly formatted
local function format_options()
    if o.frontend:sub(-1) == "/" then o.frontend = o.frontend:sub(1, -2) end
end

format_options()

list.header = ("%s Search: \\N-------------------------------------------------"):format(o.invidious and "Invidious" or "Youtube")
list.num_entries = 17
list.list_style = [[{\fs10}\N{\q2\fs25\c&Hffffff&}]]
list.empty_text = "enter search query"

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

---@param str string
---@return table[]|nil
local function json_parse_iterate(str)
    local t = {}

    local json, err, trail = utils.parse_json(str, true)
    if not json then return nil end

    repeat
        table.insert(t, json)
        json, err, trail = utils.parse_json(trail, true)
    until not json

    return t
end

local function search_ytdlp(query)
    local req = mp.command_native({
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = {o.yt_dlp_path, '-s',  ('-I1:%d'):format(o.num_results), '--flat-playlist', '-j', o.search_query:format(encode_string(query))}
    })

    msg.trace(utils.to_string(req))
    local results = json_parse_iterate(req.stdout)

    if req.status ~= 0 then
        msg.error(req.stderr)
        return nil
    end
    if not results or #results == 0 then
        msg.error("Could not parse response:")
        msg.error(req.stdout)
        return nil
    end

    return results
end

---@class SearchResult
---@field id string
---@field type 'video'|'playlist'|'channel'
---@field title string
---@field channelTitle string

---@param results table|nil
---@return SearchResult[]|nil
local function process_ytdlp_results(results)
    if not results then return nil end

    ---@type SearchResult[]
    local t = {}

    for _, v in ipairs(results) do
        local url_type = string.match(v.url, '^https://www.youtube.com/([^/?]+)')

        ---@type SearchResult
        local result = {
            id              = v.id,
            type            = url_type == 'watch' and 'video' or url_type,
            title           = v.title or '',
            channelTitle    = v.channel or '',
        }

        table.insert(t, result)
    end

    return t
end

---@param item SearchResult
local function insert_video(item)
    list:insert({
        ass = ([[%s   {\\c&aaaaaa&}%s]]):format(ass_escape(item.title), ass_escape(item.channelTitle)),
        url = ("%s/watch?v=%s"):format(o.frontend, item.id)
    })
end

---@param item SearchResult
local function insert_playlist(item)
    list:insert({
        ass = ([[{\i1}[playlist]{\i0} %s   {\\c&aaaaaa&}%s]]):format(ass_escape(item.title), ass_escape(item.channelTitle)),
        url = ("%s/playlist?list=%s"):format(o.frontend, item.id)
    })
end

---@param item SearchResult
local function insert_channel(item)
    list:insert({
        ass = ([[[{\i1}channel]{\i2} %s]]):format(ass_escape(item.title)),
        url = ("%s/channel/%s"):format(o.frontend, item.id)
    })
end

local function search(query)
    list.header = ("%s Search: %s\\N-------------------------------------------------"):format("Youtube", ass_escape(query, true))
    list.list = {}
    list.empty_text = "~"
    list:update()

    local results = process_ytdlp_results(search_ytdlp(query))

    --print error messages to console if the API request fails
    if not results then
        msg.warn("Search did not return a results list")
        return
    end

    for _, v in ipairs(results) do
        print(utils.to_string(v))
        if v.type == 'video' then insert_video(v)
        elseif v.type == 'playlist' then insert_playlist(v)
        elseif v.type == 'channel' then insert_channel(v) end
    end

    list.empty_text = "no results"
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
