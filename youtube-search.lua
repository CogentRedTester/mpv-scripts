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

    An alternative to using the official youtube API is to use Invidious.
    This script has experimental support for Invidious searches using the 'invidious',
    'API_path', and 'frontend' options. API_path refers to the url of the API the
    script uses, Invidious API paths are usually in the form:
        https://domain.name/api/v1/
    The frontend option is the url to actualy try to load videos from. This
    can probably be the same as the above url:
        https://domain.name
    Since the url syntax seems to be identical between Youtube and Invidious,
    it should be possible to mix these options, a.k.a. using the Google
    API to get videos from an Invidious frontend, or to use an Invidious
    API to get videos from Youtube.
    The 'invidious' option tells the script that the API_path is for an
    Invidious path. This is to support other possible API options in the future.
]]--

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"
local opts = require "mp.options"

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"}) .. package.path
local ui = require "user-input-module"
local list = require "scroll-list"

local o = {
    API_key = "",

    --number of search results to show in the list
    num_results = 40,

    --the url to send API calls to
    API_path = "https://www.googleapis.com/youtube/v3/",

    --attempt this API if the default fails
    fallback_API_path = "",

    --the url to load videos from
    frontend = "https://www.youtube.com",

    --use invidious API calls
    invidious = false,

    --whether the fallback uses invidious as well
    fallback_invidious = false
}

opts.read_options(o)

--ensure the URL options are properly formatted
local function format_options()
    if o.API_path:sub(-1) ~= "/" then o.API_path = o.API_path.."/" end
    if o.fallback_API_path:sub(-1) ~= "/" then o.fallback_API_path = o.fallback_API_path.."/" end
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

--creates a formatted results table from an invidious API call
function format_invidious_results(response)
    if not response then return nil end
    local results = {}

    for i, item in ipairs(response) do
        if i > o.num_results then break end

        local t = {}
        table.insert(results, t)

        t.title = html_decode(item.title)
        t.channelTitle = html_decode(item.author)
        if item.type == "video" then
            t.type = "video"
            t.id = item.videoId
        elseif item.type == "playlist" then
            t.type = "playlist"
            t.id = item.playlistId
        elseif item.type == "channel" then
            t.type = "channel"
            t.id = item.authorId
            t.title = t.channelTitle
        end
    end

    return results
end

--creates a formatted results table from a youtube API call
function format_youtube_results(response)
    if not response or not response.items then return nil end
    local results = {}

    for _, item in ipairs(response.items) do
        local t = {}
        table.insert(results, t)

        t.title = html_decode(item.snippet.title)
        t.channelTitle = html_decode(item.snippet.channelTitle)

        if item.id.kind == "youtube#video" then
            t.type = "video"
            t.id = item.id.videoId
        elseif item.id.kind == "youtube#playlist" then
            t.type = "playlist"
            t.id = item.id.playlistId
        elseif item.id.kind == "youtube#channel" then
            t.type = "channel"
            t.id = item.id.channelId
        end
    end

    return results
end

--sends an API request
local function send_request(type, queries, API_path)
    local url = (API_path or o.API_path)..type
    url = url.."?"

    for key, value in pairs(queries) do
        msg.verbose(key, value)
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
    msg.trace(utils.to_string(request))

    if request.status ~= 0 then
        msg.error(request.stderr)
        return nil
    end
    if not response then
        msg.error("Could not parse response:")
        msg.error(request.stdout)
        return nil
    end
    if response.error then
        msg.error(request.stdout)
        return nil
    end

    return response
end

--sends a search API request - handles Google/Invidious API differences
local function search_request(queries, API_path, invidious)
    list.header = ("%s Search: %s\\N-------------------------------------------------"):format(invidious and "Invidious" or "Youtube", ass_escape(queries.q, true))
    list.list = {}
    list.empty_text = "~"
    list:update()
    local results = {}

    --we need to modify the returned results so that the rest of the script can read it
    if invidious then

        --Invidious searches are done with pages rather than a max result number
        local page = 1
        while #results < o.num_results do
            queries.page = page

            local response = send_request("search", queries, API_path)
            response = format_invidious_results(response)
            if not response then msg.warn("Search did not return a results list") ; return end
            if #response == 0 then break end

            for _, item in ipairs(response) do
                table.insert(results, item)
            end

            page = page + 1
        end
    else
        local response = send_request("search", queries, API_path)
        results = format_youtube_results(response)
    end

    --print error messages to console if the API request fails
    if not results then
        msg.warn("Search did not return a results list")
        return
    end

    list.empty_text = "no results"
    return results
end

local function insert_video(item)
    list:insert({
        ass = ("%s   {\\c&aaaaaa&}%s"):format(ass_escape(item.title), ass_escape(item.channelTitle)),
        url = ("%s/watch?v=%s"):format(o.frontend, item.id)
    })
end

local function insert_playlist(item)
    list:insert({
        ass = ("🖿 %s   {\\c&aaaaaa&}%s"):format(ass_escape(item.title), ass_escape(item.channelTitle)),
        url = ("%s/playlist?list=%s"):format(o.frontend, item.id)
    })
end

local function insert_channel(item)
    list:insert({
        ass = ("👤 %s"):format(ass_escape(item.title)),
        url = ("%s/channel/%s"):format(o.frontend, item.id)
    })
end

local function reset_list()
    list.selected = 1
    list:clear()
end

--creates the search request queries depending on what API we're using
local function get_search_queries(query, invidious)
    if invidious then
        return {
            q = query,
            type = "all",
            page = 1
        }
    else
        return {
            key = o.API_key,
            q = query,
            part = "id,snippet",
            maxResults = o.num_results
        }
    end
end

local function search(query)
    local response = search_request(get_search_queries(query, o.invidious), o.API_path, o.invidious)
    if not response and o.fallback_API_path ~= "/" then
        msg.info("search failed - attempting fallback")
        response = search_request(get_search_queries(query, o.fallback_invidious), o.fallback_API_path, o.fallback_invidious)
    end

    if not response then return end
    reset_list()

    for _, item in ipairs(response) do
        if item.type == "video" then
            insert_video(item)
        elseif item.type == "playlist" then
            insert_playlist(item)
        elseif item.type == "channel" then
            insert_channel(item)
        end
    end
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
