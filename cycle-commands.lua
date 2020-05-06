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
--setting any of these to letters, numbers, or hyphens is a probably bad idea
--I only included these for future compatability, I'd suggest not changing them
o = {
    --seperates whole command lines
    cycle_seperator = '|',

    --seperates commands
    command_seperator = ';',

    --seperates words in commands
    word_seperator = ' ',
}

opt.read_options(o, 'cycle-commands')

--keeps track of commands and iterators
commands = {}
iterators = {}

--[[
the script stores the command in a table of 3D tables
the table is in the format:
    table[full string][strings between '|'][strings between ';'][strings between ' ']
Or alternatively:
    table[full string][cycle][command][word]

examples: commands['show-text hello | show-text bye'][2][1][2] = 'bye'
          commands["show-text one ; show-text 'two three' | show-text four"][1][2][2] = 'two three'
]]--
function main(str)

    --if there is nothing saved for the current string, then runs through the process of storing the commands in the table
    if commands[str] == nil then
        msg.verbose('unknown cycle, creating command table')
        iterators[str] = 0
        msg.verbose('parsing table for "' .. str)
        commands[str] = utils.parse_json(str)
    end

    --moves the iterator forward
    iterators[str] = iterators[str] + 1
    if iterators[str] > #commands[str] then
        msg.verbose('reached end of cycle, wrapping back to start')
        iterators[str] = 1
    end

    local i = iterators[str]

    msg.verbose('sending commands: ' .. utils.to_string(commands[str][i]))
    --runs each command in that cycle
    for j=1, #commands[str][i], 1 do
        --sends command native the array of words in the command
        
        local def, error = mp.command_native(commands[str][i][j], true)
        if def then
            msg.error('Error occurred for commands: ' .. utils.to_string(commands[str][i][j]))
        end
    end
end

mp.register_script_message('cycle-commands', main)
