--[[
    script to cycle commands with a keybind, accomplished through script messages
    syntax:
        script-message cycle-commands "commandline1|commandline2|commandline3"

    Everything between | is run like a normal command line in input.conf, this includes using semicolons to run multiple commands at once
    If you need to send a command with spaces, such as a multi-word string, use '_' in place of the space
    for example:
        
        script-message cycle-commands "show-text one 1000 ;  print-text two | show-text three_four"
    
    This would print 'one' to the OSD for 1 second and 'two' to the console on keypress one and 'three four' to the OSD for 3 seconds on keypress two

    There are no limits to the number of commands, and the script message can be used as often as one wants, the script stores the current iteration
    for each unique cycle command, so there should be no overlap unless one binds the exact same command string (including spacing)

    If you want to change the characters for the seperators use script-opts
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
    wordSeperator = ' ',

    --replaces spaces in command
    --necessary if one want to use multi-word strings, and spaces are set as the word seperator (default)
    replace_space_char = '_'
}

opt.read_options(o, 'cycle-commands')

--splits the string into an array of strings around the separator
function splitString(inputstr, seperator)
    local t = {}
    for str in string.gmatch(inputstr, "([^"..seperator.."]+)") do
            table.insert(t, str)
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
        iterators[str] = 1

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
                local t = splitString(commands[str][i][j], o.wordSeperator)
                msg.debug(utils.to_string(t))
                commands[str][i][j] = t

                --changes all alternate space characters to spaces
                for k=1, #t, 1 do
                    commands[str][i][j][k] = string.gsub(commands[str][i][j][k], o.replace_space_char, ' ')
                end
            end
        end

        msg.verbose('command table complete')
    end

    local i = iterators[str]

    --runs each command in that cycle
    for j=1, #commands[str][i], 1 do

        --sends command native the array of words in the command
        mp.command_native(commands[str][i][j])
    end

    --moves the iterator forward
    iterators[str] = iterators[str] + 1
    if iterators[str] > #commands[str] then
        msg.verbose('reached end of profiles, wrapping back to start')
        iterators[str] = 1
    end
end

mp.register_script_message('cycle-commands', main)