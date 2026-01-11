--[[
    This script allows users to search and open youtube results from within mpv using yt-dlp.
    Available at: https://github.com/CogentRedTester/mpv-scripts

    The Y button opens the latest page of search results (or prompts for input
    if nothing has yet been searched).
    The search page has an entry to do a new search.
    Alternatively, Ctrl+y can be used at any time to open a search.
    Esc can be used to close the page.

    yt-dlp must also be available in the system path
]]--

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"
local opts = require "mp.options"
local input = require 'mp.input'

local o = {
    --Number of search results to show in the list.
    num_results = 40,

    --The url to send API calls to.
    yt_dlp_path = "yt-dlp",

    --The search query to sent to yt-dlp. `%s` is substituted for the search query.
    search_query = "https://www.youtube.com/search?q=%s",

    frontend = "https://www.youtube.com",

    --Save search history between mpv sessions.
    save_search_history = true,
}

opts.read_options(o)

--ensure the URL options are properly formatted
local function format_options()
    if o.frontend:sub(-1) == "/" then o.frontend = o.frontend:sub(1, -2) end
end

format_options()

---@class SearchResult
---@field id string
---@field type 'video'|'playlist'|'channel'
---@field title string
---@field channelTitle string
---@field url string

---@class LatestSearch
---@field latest_results SearchResult[]
---@field query string
---@field display_list string[]

---@type LatestSearch|nil
local latest_search = nil

local selection_open = false

---encodes a string so that it uses url percent encoding
---this function is based on code taken from here: https://rosettacode.org/wiki/URL_encoding#Lua
---@param str string
---@return string
local function encode_string(str)
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

---@param query string
---@return table[]|nil
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
            url             = url_type == 'watch' and ("%s/watch?v=%s"):format(o.frontend, v.id)
                              or url_type == 'playlist' and ("%s/playlist?list=%s"):format(o.frontend, v.id)
                              or url_type == 'channel' and ("%s/channel/%s"):format(o.frontend, v.id)
                              or ''
        }

        table.insert(t, result)
    end

    return t
end

---@alias PlayFlag 'play'|'append'|'new-window'

---@param index number
---@param flag PlayFlag
local function play(index, flag)
    if not index or not latest_search then return end
    local item = latest_search.latest_results[index]

    if flag == 'new-window' then
        mp.commandv('run', 'mpv', item.url)
    elseif flag == 'append' then
        mp.command_native({"loadfile", item.url, 'append-play'})
    else
        mp.command_native({"loadfile", item.url})
    end
end

---@type [string,string,PlayFlag][]
local custom_select_keybinds = {
    {'Shift+Enter', 'select/append', 'append'},
    {'Shift+MBTN_LEFT', 'select/append/mbtn', 'append'},
    {'Ctrl+Enter', 'select/new-window', 'new-window'},
    {'Ctrl+MBTN_LEFT', 'select/new-window/mbtn', 'new-window'},
}

local function show_results()
    if not latest_search then return msg.error('no search results available to display') end
    selection_open = true

    local items = {'~~ NEW SEARCH ~~', unpack(latest_search.display_list)}
    ---@type PlayFlag
    local flag = 'play'

    input.select({
        id = mp.get_script_name()..'/select-results',
        prompt = ('Results for: %s | Filter: '):format(latest_search.query),
        items = items,
        default_item = 1,
        keep_open = true,
        opened = function()
            msg.debug('Select prompt opened - adding keybinds')

            for _, keybind in ipairs(custom_select_keybinds) do
                mp.add_forced_key_binding(keybind[1], keybind[2], function()
                    flag = keybind[3]
                    mp.commandv('keypress', 'enter')
                end)

                -- This is necessary because of a race condition that sometimes
                -- causes the console keybinds to take precedence over ours
                -- despite us declaring ours after.
                if keybind[1]:find('Shift') then
                    mp.add_timeout(0.5, function()
                        mp.add_forced_key_binding(keybind[1], keybind[2], function()
                            flag = keybind[3]
                            mp.commandv('keypress', 'enter')
                        end)
                    end)
                end
            end
        end,
        closed = function()
            msg.debug('selection closed - removing keybinds')
            for _, keybind in ipairs(custom_select_keybinds) do
                mp.remove_key_binding(keybind[2])
            end
            mp.remove_key_binding('_console_text')
        end,
        submit = function(i)
            -- the first item is the option to do a new search
            if i == 1 then
                input.terminate()
                mp.add_timeout(0.1, open_search_input)
            else
                play(i-1, flag)
            end

            if flag == 'play' then
                input.terminate()
                selection_open = false
            else
                flag = 'play'
            end
        end,
    })
end

---@param query string
local function search(query)

    ---@type string[]
    local display_list = {}
    local results = process_ytdlp_results(search_ytdlp(query))

    --print error messages to console if the API request fails
    if not results then
        msg.warn("Search did not return a results list")
        return
    end

    for _, v in ipairs(results) do
        if v.type == 'video' then
            table.insert(display_list, ('%s —\t%s'):format(v.channelTitle, v.title))
        elseif v.type == 'channel' then
            table.insert(display_list, ('~Channel~\t%s'):format(v.title))
        else
            table.insert(display_list, ('~Playlist~\t%s'):format(v.title))
        end
    end

    latest_search = {
        query = query,
        latest_results = results,
        display_list = display_list
    }
    show_results()
end

---@diagnostic disable-next-line: lowercase-global
function open_search_input()
    input.get({
        id = mp.get_script_name()..'/enter-search-query',
        prompt = 'Youtube Search:\n> ',
        history_path = '~~state/youtube_search_history',
        submit = function(line)
            -- We must add this function to the event queue as the
            -- 'closed' event (that removes the input handler) is sent at the
            -- same time as submit. We must give it a chance to run before doing
            -- the search so that the select prompt can receive input.
            -- We are not using keep-open as there is still a delay
            -- before the search completes and we don't want the input to remain open.
            mp.add_timeout(0.1, function() search(line) end)
            mp.osd_message(('Searching Youtube for "%s"'):format(line))
            input.terminate()
        end
    })
end

mp.add_key_binding("Ctrl+y", "yt", function()
    input.terminate()
    mp.add_timeout(0.1, open_search_input)
end)

mp.add_key_binding("Y", "youtube-search", function()
    if selection_open or latest_search == nil then open_search_input()
    else show_results() end
end)

