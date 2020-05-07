--[=====[
    script to cycle commands with a keybind, accomplished through script messages
    syntax:
        script-message cycle-commands [[commandline1],[commandline2],[commandline3]]

    The syntax is in the form of a triple nested Json array. The top level array corresponds to each cycle, the 2nd level to each command in each cycle,
    and the bottom level array to each argument in the command.
    Double quotes must be used for each argument string, and a comma needs to be between each option.
    Below is an example that sends two commands on the first keypress, and one on the second (spaces not necessary):
    
        script-message cycle-commands [ [["show-text","one","1000"] , ["print-text","two"]] , [["show-text","three four"]] ]
    
    This would, on keypress one, print 'one' to the OSD for 1 second and 'two' to the console, on keypress two 'three four' would be printed to the OSD

    There are no limits to the number of commands, and the script message can be used as often as one wants, the script stores the current iteration
    for each unique cycle command, so there should be no overlap unless one binds the exact same command string (including spacing)

    If the command isn't working and you have the whole array inside quotes, try removing them
]=====]--


msg = require 'mp.msg'
utils = require 'mp.utils'

--keeps track of commands and iterators
cmd = {}

--[=====[

    the script stores the command in a table of 3D tables
    the table is in the format:
        table[full string].table[cycle][command][word]
        table[full string].iterator

    examples: cmd['[[["show-text","hello"]],[["show-text","bye"]]]'].str[2][1][2] = 'bye'
            cmd['[[["show-text","one"],["show-text","two three"]],[["show-text","four"]]]'].str[1][2][2] = 'two three'

]=====]--
function main(...)

    --mpv seems to have trouble parsing strings like this, by using a variable argument function
    --we can just concatenate all the substrings into one big string
    str = ""
    for i,v in ipairs({...}) do
        str = str .. " " .. v
    end
    msg.debug('recieved ' .. str)

    --if there is nothing saved for the current string, then runs through the process of storing the commands in the table
    if cmd[str] == nil then
        msg.verbose('unknown cycle, creating command table')
        cmd[str] = {}
        cmd[str].iterator = 0
        msg.verbose('parsing table for "' .. str)
        cmd[str].table = utils.parse_json(str)
    end

    if cmd[str].table == nil then
        msg.error('command syntax incorrect for string: ' .. str)
        msg.error('if you see quotes around the above string then try removing them from input.conf')
        return
    end

    --moves the iterator forward
    cmd[str].iterator = cmd[str].iterator + 1
    if cmd[str].iterator > #cmd[str].table then
        msg.verbose('reached end of cycle, wrapping back to start')
        cmd[str].iterator = 1
    end

    local i = cmd[str].iterator

    msg.verbose('sending commands: ' .. utils.to_string(cmd[str].table[i]))
    --runs each command in that cycle
    for j=1, #cmd[str].table[i], 1 do
        --sends command native the array of words in the command
        
        local def, error = mp.command_native(cmd[str].table[i][j], true)
        if def then
            msg.error('Error occurred for commands: ' .. utils.to_string(cmd[str].table[i][j]))
        end
    end
end

mp.register_script_message('cycle-commands', main)
