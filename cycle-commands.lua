--[=====[
    script to cycle commands with a keybind, accomplished through script messages
    syntax:
        script-message cycle-commands [[commandline1],[commandline2],[commandline3]]

    The syntax is in the form of a triple nested json array. The top level array corresponds to each cycle, the 2nd level to each command in each cycle,
    and the bottom level array to each argument in the command.
    Double quotes must be used for each argument string, and a comma needs to be between each option.
    Below is an example that sends two commands on the first keypress, and one on the second:
    
        script-message cycle-commands [[["show-text","one","1000"],["print-text","two"]],[["show-text","three four"]]]
    
    This would, on keypress one, print 'one' to the OSD for 1 second and 'two' to the console, on keypress two 'three four' would be printed to the OSD

    There are no limits to the number of commands, and the script message can be used as often as one wants, the script stores the current iteration
    for each unique cycle command, so there should be no overlap unless one binds the exact same command string (including spacing)

    String Quoting:
        The script is designed to be sent strings directly from input.conf without being encapsulated in quotes. By this I mean you shouldn't need to put
        quotes around the whole input string as long as the below special rules are followed. However, if one does choose to do full quoting
        then care needs to be taken that all the quotation marks inside the string are properly escaped using a backslash `\`.

        Full quoting can potentially solve some edge case inputs, so if your command isn't working try this.
        Example:
            script-message cycle-commands "[[[\"show-text\",\"one\",\"1000\"],[\"print-text\",\"two\"]],[[\"show-text\",\"three four\"]]]"

    Special rules:
        spaces:     Generally it doesn't matter where you put spaces, the script can handle spaces anywhere in the json string,
                    however, you need to take into account the following requirement

        quotes:     Each argument in the command must contain double quotes as part of the string that is sent to the script,
                    however, if the quotes have whitespace directly outside them, mpv will automatically strip the quotes and send
                    just the characters inside. In this situatiuon you need to place double quote characters inside the string,
                    and use a backslash `\` to escape them. Example:
                        script-message cycle-commands [[["show-text", "\"hello\"" ]],[["show-text","two"]]]

                    Note that does not apply if the whole script message is quoted, as described above.

        special     Some special characters, such as `#`, will require a properly quoted string in order to be sent to the script, for these
        chars:      characters either the above formatting, or the full quotation method descibed further above is required.
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
    --to make the command syntax easier we will accept multiple substrings
    --and concatenate them together into the full json string
    str = ""
    for _,v in ipairs({...}) do
        str = str .. " " .. v
    end
    msg.debug('recieved: ' .. str)

    --if there is nothing saved for the current string, then runs through the process of storing the commands in the table
    if cmd[str] == nil then
        msg.verbose('unknown cycle, creating command table')
        cmd[str] = {}
        cmd[str].iterator = 0
        msg.verbose('parsing table for: ' .. str)
        cmd[str].table = utils.parse_json(str)
    end

    if cmd[str].table == nil then
        msg.error('command syntax incorrect for string: ' .. str)
        msg.info('if you see quotes around the above string then try removing them from input.conf')
        return
    end

    --moves the iterator forward
    cmd[str].iterator = cmd[str].iterator + 1
    if cmd[str].iterator > #cmd[str].table then
        msg.verbose('reached end of cycle, wrapping back to start')
        cmd[str].iterator = 1
    end

    local i = cmd[str].iterator

    --runs each command in that cycle
    msg.verbose('sending commands: ' .. utils.format_json(cmd[str].table[i]))
    for _,command in ipairs(cmd[str].table[i]) do
        local def, err = mp.command_native(command, true)
        if def then
            msg.error(err .. ' for command: ' .. utils.format_json(command))
        end
    end
end

mp.register_script_message('cycle-commands', main)
