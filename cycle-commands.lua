--[[
    script to cycle commands with a keybind, accomplished through script messages
    syntax:
        script-message cycle-commands "commandline1|commandline2|commandline3"

    Everything between | is run like a normal command line in input.conf, this includes using semicolons to run multiple commands at once
    If you need to send a command using multi-word strings use quotation marks.
    for example:
        
        script-message cycle-commands "show-text one 1000 ;  print-text two | show-text 'three four'"
    
    This would, on keypress one, print 'one' to the OSD for 1 second and 'two' to the console, on keypress two 'three four' would be printed to the OSD

    There are no limits to the number of commands, and the script message can be used as often as one wants, the script stores the current iteration
    for each unique cycle command, so there should be no overlap unless one binds the exact same command string (including spacing)

    If you want to change the characters for the seperators use script-opts, however, I haven't tested this script with any other characters,
    so I can't guarantee they'll work. I recommend not changing anything.
]]--


msg = require 'mp.msg'
utils = require 'mp.utils'
opt = require 'mp.options'

--set the characters to use as seperators
--setting any of these to letters, numbers, or hyphens is a VERY bad idea
o = {
    --seperates whole command lines
    cycle_seperator = '|',

    --seperates commands
    command_seperator = ';',

    --seperates words in commands
    word_seperator = ' ',
}

opt.read_options(o, 'cycle-commands')

--tests if the character at the specified position is a seperator character
function is_seperator(inputstr, position)
    local sep = inputstr:find('['..o.cycle_seperator .. o.command_seperator .. o.word_seperator..']', position)

    if sep == position then
        return true
    else
        return false
    end
end

--splits the string into an array of strings around the separator
function splitString(inputstr, seperator)
    local t = {}
    msg.debug('splitting "' .. inputstr .. '" around "' .. seperator .. '"')

    while inputstr ~= "" do
        local endstr
        local char = ""
        msg.debug('operating on string "' .. inputstr .. '"')

        --removes all the seperator characters from the front of the substring
        while is_seperator(inputstr, 1) do
            inputstr = inputstr:sub(2)
        end

        --testing if the first character is a quote
        local quote = inputstr:find('["\']')
        if quote == 1 then
            msg.verbose('quote found, encapsulating string')
            char = inputstr:sub(1, 1)
            --removing first quote from string
            inputstr = inputstr:sub(2)

            --finding the end of the quotes
            endstr = inputstr:find(char, 2)
        else
            --if no quote is found then it finds the next seperator
            endstr = inputstr:find(seperator)
        end

        --sets the end of the string to the full length if nothing could be found
        if endstr == nil then
            endstr = inputstr:len()
        end

        --removes extra seperator characters from the end of the substring (put them in quotes if you want them)
        local newstr = inputstr:sub(1, endstr)
        msg.debug('operating on substring "' .. newstr .. '"')
        while is_seperator(newstr, newstr:len()) do
            endstr = endstr - 1
            newstr = inputstr:sub(1, endstr)
        end

        --removes the last character if it's a quote and the first character of the substring is also a quote
        if newstr:find(char, -1) and quote == 1 then
            msg.debug('removing end quote')
            inputstr = inputstr:sub(0, endstr - 1) .. inputstr:sub(endstr + 1)
        end

        newstr = inputstr:sub(1, endstr)
        msg.verbose('inserting "' .. newstr .. '" to table')
        table.insert(t, newstr)
        inputstr = inputstr:sub(endstr + 1)
    end
    return t
end

--keeps track of commands and iterators
commands = {}
iterators = {}

--[[
the script stores the command in a 4D table
the table is in the format:
    table[full string][strings between '|'][strings between ';'][strings between ' ']
Or alternatively:
    table[full string][cycle][command][word]

examples: commands['show-text hello | show-text bye'][2][1][2] = 'bye'
          commands['show-text one ; show-text two | show-text three'][1][2][2] = 'two'
]]--
function main(str)

    --if there is nothing saved for the current string, then runs through the process of storing the commands in the table
    if commands[str] == nil then
        iterators[str] = 0

        msg.verbose('unknown cycle, creating command table')

        --splits each cycle around the character '|'
        local t = splitString(str, o.cycle_seperator)
        commands[str] = t
        msg.debug(utils.to_string(t))

        --splits each command in each cycle around ';'
        for i=1, #commands[str], 1 do
            local t = splitString(commands[str][i], o.command_seperator)
            msg.debug(utils.to_string(t))
            commands[str][i] = t

            --splits each word in each command around ' '
            for j=1, #commands[str][i], 1 do
                local t = splitString(commands[str][i][j], o.word_seperator)
                msg.debug(utils.to_string(t))
                commands[str][i][j] = t
            end
        end

        msg.verbose('command table complete')
    end

    --moves the iterator forward
    iterators[str] = iterators[str] + 1
    if iterators[str] > #commands[str] then
        msg.verbose('reached end of cycle, wrapping back to start')
        iterators[str] = 1
    end

    local i = iterators[str]

    --runs each command in that cycle
    for j=1, #commands[str][i], 1 do
        --sends command native the array of words in the command
        local def, error = mp.command_native(commands[str][i][j], true)
        if def then
            msg.error('Error occurred for command: ' .. utils.to_string(commands[str][i][j]))
        end
    end
end

mp.register_script_message('cycle-commands', main)
