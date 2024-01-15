--[=====[
    script to cycle commands with a keybind, accomplished through script messages
    available at: https://github.com/CogentRedTester/mpv-scripts

    syntax:
        script-message cycle-commands "command1 args" "command2 args" "command3 args"

    The syntax of each command is identical to the standard input.conf syntax, but each command must be
    a quoted string. Note that this may require you to nest (and potentially escape) quotes for the arguments.
    Read the mpv documentation for how to do this: https://mpv.io/manual/master/#flat-command-syntax.

    Semicolons also work exactly like they do normally, so you can easily send multiple commands each cycle.

    Here are some examples of the same command using different quotes:
        script-message cycle-commands "show-text one 1000 ; print-text two" "show-text \"three four\""
        script-message cycle-commands 'show-text one 1000 ; print-text two' 'show-text "three four"'
        script-message cycle-commands ``show-text one 1000 ; print-text two`` ``show-text "three four"``

    This would, on keypress one, print 'one' to the OSD for 1 second and 'two' to the console,
    and on keypress two 'three four' would be printed to the OSD.
    Note that single (') and backtick (`) quoting was only added in mpv v0.34.

    There are no limits to the number of commands, and the script message can be used as often as one wants,
    the script stores the current iteration for each unique cycle command, so there should be no overlap
    unless one binds the exact same set of command strings (including spacing).

    Most commands should print messages to the OSD automatically, this can be controlled
    by adding input prefixes to the commands: https://mpv.io/manual/master/#input-command-prefixes.
    Some commands will not print an osd message even when told to, in this case you have two options:
    you can add a show-text command to the cycle, or you can use the cycle-command/osd script message
    which will print the command string to the osd. For example:
        script-message cycle-commands 'apply-profile profile1;show-text "applying profile1"' 'apply-profile profile2;show-text "applying profile2"'
        script-message cycle-commands/osd 'apply-profile profile1' 'apply-profile profile2'

    Any osd messages printed by the command will override the message sent by cycle-command/osd.
]=====]--

local mp = require 'mp'
local msg = require 'mp.msg'

--keeps track of the current position for a specific cycle
local iterators = {}

--main function to identify and run the cycles
local function main(osd, ...)
    local commands = {...}

    --to identify the specific cycle we'll concatenate all the strings together to use as our table key
    local str = table.concat(commands, " | ")
    msg.trace('recieved:', str)

    if iterators[str] == nil then
        msg.debug('unknown cycle, creating iterator')
        iterators[str] = 1
    else
        iterators[str] = iterators[str] + 1
        if iterators[str] > #commands then iterators[str] = 1 end
    end

    --mp.command should run the commands exactly as if they were entered in input.conf.
    --This should provide universal support for all input.conf command syntax
    local cmd = commands[ iterators[str] ]
    msg.verbose('sending command:', cmd)
    if osd then mp.osd_message(cmd) end
    mp.command(cmd)
end

mp.register_script_message('cycle-commands', function(...) main(false, ...) end)
mp.register_script_message('cycle-commands/osd', function(...) main(true, ...) end)
