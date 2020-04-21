--[[
    This script automatically loads external coverart files into mpv as additional video tracks.

    By default the script searches the folder than the current file is from, but it can also search in
    the parent folder and the current playlist. By default the script will automatically search the playlist
    if it can't access the directory of the current file (usually when playing a network file).

    Look at the below for the full list of options, see the mpv manual for how to set options (the osc chapter has good examples)
    the option prefix is 'coverart-'
]]--

--list of options
local o = {
    --list of names of valid cover art, must be separated by semicolons with no spaces
    --the script is not case specific
    --any file with valid names and valid image extensions are loaded
    --if set to blank then image files with any name will be loaded
    names = "cover;folder;album;front",

    --valid image extensions, same syntax as the names option
    --leaving it blank will load files of any type (with the matching filename)
    --leaving both lists blank is not a good idea
    imageExts = 'jpg;jpeg;png;bmp;gif',

    --by default it only loads coverart if it detects the file is an audio file
    --an audio file is one with zero video tracks, or one where the first video track has < 2 fps (an image)
    --if this option is set to true then it will search for coverart on every file
    always_scan_coverart = false,

    --file path of a placeholder image to use if no cover art is found
    --will only be used if force-window is enabled
    --leaving it blank will be the same as disabling it
    placeholder = "",

    --searches for valid coverart in the filesystem
    load_from_filesystem = true,

    --search for valid coverart in the current playlist
    --this may seem pointless, but it's useful for streaming from
    --network file servers which mpv can't usually scan
    load_from_playlist = false,

    --If this is enabled then only valid coverart in the playlist that is
    --also in the same directory as the currently playing file will be loaded.
    --If disabled, then any valid coverart in the playlist will be loaded.
    enforce_playlist_directory = true,

    --scans the parent directory for coverart as well, this
    --currently doesn't do anything when loading from a playlist
    check_parent = false,

    --attempts to load from playlist automatically if it can't access the filesystem
    auto_load_from_playlist = true
}

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'
local opt = require 'mp.options'

local names = {}
local imageExts = {}

--splits the string into a table on the semicolons
function create_table(input)
    local t={}
    for str in string.gmatch(input, "([^;]+)") do
            t[str] = true
    end
    return t
end

--a music file has no video track, or the video track is less than 2 fps (an image file)
function is_audio_file()
    if mp.get_property_number('vid', 0) == 0 then
        return true
    else
        if mp.get_property_number('container-fps', 0) < 2 and mp.get_property_number('aid', 0) ~= 0 then
            return true
        end
    end
    return false
end

--processes the option strings to ensure they work with the script
function processStrings()
    --sets everything to lowercase to avoid confusion
    o.names = string.lower(o.names)
    o.imageExts = string.lower(o.imageExts)

    --splits the strings into tables
    names = create_table(o.names)
    imageExts = create_table(o.imageExts)
end

--loads a placeholder image as cover art for the file
function loadPlaceholder()
    if o.placeholder == "" then return end

    if not (mp.get_property('vid') == "no" and mp.get_property_bool('force-window')) then return end

    msg.verbose('file does not have video track, loading placeholder')
    local placeholder = mp.command_native({"expand-path", o.placeholder})
    mp.commandv('video-add', placeholder)
end

--checks if the given file matches the cover art requirements
function isValidCoverart(file)
    msg.verbose('testing if ' .. file .. ' is valid coverart')
    local filename, fileext = splitFileName(file)

    if o.imageExts ~= "" and not imageExts[fileext] then
        msg.debug('"' .. fileext .. '" not in whitelist')
        return false
    else
        msg.debug('"' .. fileext .. '" in whitelist, checking for valid name...')
    end
    if o.names == "" or names[filename] then
        msg.debug('filename valid')
        return true
    end
    msg.debug('filename invalid')
    return false
end

--splits filename into a name and extension
function splitFileName(file)
    file = string.lower(file)

    --finds the file extension
    local index = file:find([[.[^.]*$]])
    local fileext = file:sub(index + 1)

    --find filename
    local filename = file:sub(0, index - 1)

    return filename, fileext
end

--loads the coverart
function loadCover(path)
    --adds the new file to the playing list
    --if there is no video track currently selected then it autoloads track #1
    if mp.get_property_number('vid', 0) == 0 then
        mp.commandv('video-add', path)
    else
        mp.commandv('video-add', path, "auto")
    end
end

--searches and adds valid coverart from the specified directory
function addFromDirectory(directory)
    local files = utils.readdir(directory, "files")
    if files == nil then
        msg.verbose('no files could be loaded from ' .. directory)
        return false
    else
        msg.verbose('scanning files in ' .. directory)
    end

    --loops through the all the files in the directory to find if any are valid cover art
    for i, file in ipairs(files) do
        --if the name matches one in the whitelist then load it
        if isValidCoverart(file) then
            msg.verbose(file .. ' found in whitelist - adding as extra video track...')
            loadCover(utils.join_path(directory, file))
        end

        ::continue::
    end
    return true
end

function checkForCoverart()
    --does not look for cover art if the file is not ana audio file
    if not o.always_scan_coverart and not is_audio_file() then
        msg.verbose('file is not an audio file, aborting coverart search')
        loadPlaceholder()
        return
    end

    --finds the local directory of the file
    local workingDirectory = mp.get_property('working-directory')
    msg.verbose('working-directory: ' .. workingDirectory)
    local filepath = mp.get_property('path')
    msg.verbose('filepath: ' .. filepath)
    local exact_path = utils.join_path(workingDirectory, filepath)
    msg.verbose('full path: ' .. exact_path)

    --splits the directory and filename apart
    local directory = utils.split_path(exact_path)
    msg.verbose('directory: ' .. directory)

    local succeeded
    if o.load_from_filesystem then
        --loads the files from the directory
        succeeded = addFromDirectory(directory)

        if o.check_parent and succeeded then
            addFromDirectory(directory .. "/../")
        end
    end
    if ((not succeeded) and o.auto_load_from_playlist) or o.load_from_playlist then
        --loads files from playlist
        msg.info('searching for coverart in current playlist')
        local pls = mp.get_property_native('playlist')
        
        for i,v in ipairs(pls)do
            local dir, name = utils.split_path(v.filename)
            if (not o.enforce_playlist_directory) or utils.join_path(workingDirectory, dir) == directory then
                if isValidCoverart(name) then
                    msg.verbose('found cover in playlist')
                    loadCover(v.filename)
                end
            end
            ::continue::
        end
    end

    --loads a placeholder image if no covers were found and a window is forced
    loadPlaceholder()
end

opt.read_options(o, 'coverart')
processStrings()

--runs automatically whenever a file is loaded
mp.register_event('file-loaded', checkForCoverart)

--to force an update during runtime
mp.register_script_message('load-coverart', checkForCoverart)