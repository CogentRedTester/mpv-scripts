--[=====[
    script to cycle commands with a keybind, accomplished through script messages
    available at: https://github.com/CogentRedTester/mpv-scripts

    syntax:
        script-message cycle-commands "command1" "command2" "command3"

    The syntax of each command is identical to the standard input.conf syntax, but each command must be
    a single quoted string. Note that this may require you to nest (and potentially escape) quotes,
    read the mpv documentation for how to do this: https://mpv.io/manual/master/#flat-command-syntax.

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
    unless one binds the exact same command string (including spacing).
]=====]--

local mp = require 'mp'
local msg = require 'mp.msg'

--keeps track of the current position for a specific cycle
local iterators = {}

--main function to identify and run the cycles
local function main(...)
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
    mp.command(cmd)
end

mp.register_script_message('cycle-commands', main)
