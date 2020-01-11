--this script automatically scans the directory of the currently open file for valid external cover art and automatically loads it into mpv player
--I can only confirm that this works on windows, I have not tested it on any other platform, however it should be simple to adapt by modifying the checkForCoverart function

utils = require 'mp.utils'
msg = require 'mp.msg'
opt = require 'mp.options'

local o = {
    --list of names of valid cover art, must be separated by semicolons with no spaces
    --the script is not case specific
    --any file with valid filenames and valid image extensions are loaded
    filenames = "cover;folder;album;front",

    --ignore the filename and load all image files
    load_all = false,

    --valid image extensions, same syntax as the filenames option
    --leaving it blank will load files of any type (with the matching filename)
    imageExts = 'jpg;jpeg;png;bmp;gif',

    --only loads cover art when playing files with these extensions
    --setting it to blank will cause the script to treat all files as audio files
    audioExts = 'mp3;wav;ogm;flac;m4a;wma;ogg;opus;alac;mka;aiff',

    --file path of a placeholder image to use if no cover art is found
    --will only be used if force-window is enabled
    --leaving it blank will be the same as disabling it
    placeholder = "",

    --load the placeholder for all files, not just ones that match the audio extension whitelist
    --still only activates the placeholder when force-window is enabled
    always_use_placeholder = true
}

local filenames = {}
local imageExts = {}
local audioExts = {}

--splits the string into a table on the semicolons
function create_table(input)
    local t={}
    for str in string.gmatch(input, "([^;]+)") do
            t[str] = true
    end
    return t
end

--returns true if the variable exists in the table
function in_table(var, t)
    return t[var]
end

--processes the option strings to ensure they work with the script
function processStrings()
    --sets everything to lowercase to avoid confusion
    o.filenames = string.lower(o.filenames)
    o.imageExts = string.lower(o.imageExts)
    o.audioExts = string.lower(o.audioExts)

    --splits the strings into tables
    filenames = create_table(o.filenames)
    imageExts = create_table(o.imageExts)
    audioExts = create_table(o.audioExts)
end

--loads a placeholder image as cover art for the file
function loadPlaceholder()
    if o.placeholder == "" then return end

    if not (mp.get_property('vid') == "no" and mp.get_property_bool('force-window')) then return end

    msg.verbose('file does not have video track, loading placeholder')
    local path = mp.command_native({"expand-path", o.placeholder})
    mp.commandv('video-add', path)
end

function checkForCoverart()
    --finds the local directory of the file

    local workingDirectory = mp.get_property('working-directory')
    msg.verbose('working-directory: ' .. workingDirectory)
    local filepath = mp.get_property('path')
    msg.verbose('filepath: ' .. filepath)

    --does not look for cover art if the file does not have a valid extension
    local ext = filepath:sub(filepath:find([[.[^.]*$]]) + 1)
    msg.verbose('file extension: ' .. ext)
    if o.audioExts ~= "" and not in_table(ext, audioExts) then
        msg.verbose('file does not have valid extension, aborting coverart search')
        --loads a placeholder image if no covers were found and a window is forced
        if o.always_use_placeholder then
            loadPlaceholder()
        end
        return
    end

    --converts the string into a compatible path for mpv to parse
    --only confirmed to work in windows, this is the part that may need to be changed for other operating systems
    local path = utils.join_path(workingDirectory, filepath)
    msg.verbose('full path: ' .. path)
    path = path:gsub([[/.\]], [[/]])
    path = path:gsub([[\]], [[/]])
    msg.verbose('standardising characters, new path: ' .. path)

    --splits the directory and filename apart
    local directory, filename = utils.split_path(path)
    msg.verbose('directory: ' .. directory)

    --loads the files from the directory
    files = utils.readdir(directory, "files")

    --loops through the all the files in the directory to find if any are valid cover art
    msg.verbose('scanning files in ' .. directory)
    for i = 1, #files, 1 do
        msg.debug('found file: ' .. files[i])
        local file = string.lower(files[i])

        --finds the file extension
        local index = string.find(file, [[.[^.]*$]])
        local fileext = file:sub(index + 1)

        --if file extension is not an image then moves to the next file
        if o.imageExts ~= "" and not in_table(fileext, imageExts) then
            msg.debug('"' .. fileext .. '" not in whitelist')
            goto continue
        else
            msg.debug('"' .. fileext .. '" in whitelist')
        end

        --sets the file name
        local filename = file:sub(0, index - 1)

        --if the name matches one in the whitelist
        if in_table(filename, filenames) or o.load_all then
            msg.verbose(file .. ' found in whitelist - adding as extra video track...')
            local path = utils.join_path(directory, file)

            --adds the new file to the playing list
            --if there is no video track currently selected then it autoloads track #1
            if mp.get_property_number('vid', 0) == 0 then
                mp.commandv('video-add', path)
            else
                mp.commandv('video-add', path, "auto")
            end
        end

        ::continue::
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