local utils = require 'mp.utils'
local settings = {

    --filetypes,{'mp4','mkv'} for specific or {''} for all filetypes
    filetypes = {'mkv', 'avi', 'mp4', 'ogv', 'webm', 'rmvb', 'flv', 'wmv', 'mpeg', 'mpg', 'm4v', '3gp',
'mp3', 'wav', 'ogv', 'flac', 'm4a', 'wma', 'jpg', 'gif', 'png', 'jpeg', 'webp'}, 

    --linux(true)/windows(false)/auto(nil)
    linux_over_windows = nil,

    --at end of directory jump to start and vice versa
    allow_looping = true,

}
--check os
if settings.linux_over_windows==nil then
  local o = {}
  if mp.get_property_native('options/vo-mmcss-profile', o) ~= o then
    settings.linux_over_windows = false
  else
    settings.linux_over_windows = true
  end
end

function nexthandler()
    movetofile(true)
end

function prevhandler()
    movetofile(false)
end

function escapepath(dir, escapechar)
  return string.gsub(dir, escapechar, '\\'..escapechar)
end

function movetofile(forward)
    if mp.get_property('filename'):match("^%a%a+:%/%/") then return end
    local pwd = mp.get_property('working-directory')
    local relpath = mp.get_property('path')
    if not pwd or not relpath then return end

    local path = utils.join_path(pwd, relpath)
    local file = mp.get_property("filename")
    local dir = utils.split_path(path)

    local search = ' '
    for w in pairs(settings.filetypes) do
        if settings.linux_over_windows then
            search = search.."*."..settings.filetypes[w]..' '
        else
            search = search..'"'..escapepath(dir, '"').."*."..settings.filetypes[w]..'" '
        end
    end

    local popen, err = nil, nil
    if settings.linux_over_windows then
        popen, err = io.popen('cd "'..escapepath(dir, '"')..'";ls -1p'..search..'2>/dev/null')
    else
        popen, err = io.popen('dir /b'..(search:gsub("/", "\\")))
    end
    if popen then
        local found = false
        local memory = nil
        local lastfile = true
        local firstfile = nil
        for dirx in popen:lines() do
            if found == true then
                mp.commandv("loadfile", dir..dirx, "replace")
                lastfile=false
                break
            end
            if dirx == file then
                found = true
                if not forward then
                    lastfile=false 
                    if settings.allow_looping and firstfile==nil then 
                        found=false
                    else
                        if firstfile==nil then break end
                        mp.commandv("loadfile", dir..memory, "replace")
                        break
                    end
                end
            end
            memory = dirx
            if firstfile==nil then firstfile=dirx end
        end
        if lastfile and firstfile and settings.allow_looping then
            mp.commandv("loadfile", dir..firstfile, "replace")
        end
        if not found and memory then
            mp.commandv("loadfile", dir..memory, "replace")
        end
        popen:close()
    else
        mp.msg.error("could not scan for files: "..(err or ""))
    end
end

mp.add_key_binding('shift+RIGHT', 'nextfile', nexthandler)
mp.add_key_binding('shift+LEFT', 'previousfile', prevhandler)
