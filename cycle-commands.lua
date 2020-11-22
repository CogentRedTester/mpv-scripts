--[=====[
    script to cycle commands with a keybind, accomplished through script messages
    available at: https://github.com/CogentRedTester/mpv-scripts

    syntax:
        script-message cycle-commands "command1" "command2" "command3"

    The syntax of each command is identical to the standard input.conf syntax, but each command must be within
    a pair of double quotes.

    Commands with mutiword arguments require you to send double quotes just like normal command syntax, however,
    you will need to escape the quotes with a backslash so that they are sent as part of the string.
    Semicolons also work exactly like they do normally, so you can easily send multiple commands each cycle.

    Here is an example of a standard input.conf entry:

        script-message cycle-commands "show-text one 1000 ; print-text two" "show-text \"three four\""

    This would, on keypress one, print 'one' to the OSD for 1 second and 'two' to the console,
    and on keypress two 'three four' would be printed to the OSD.
    Notice how the quotation marks around 'three four' are escaped using backslashes.
    All other syntax details should be exactly the same as usual input commands.

    There are no limits to the number of commands, and the script message can be used as often as one wants,
    the script stores the current iteration for each unique cycle command, so there should be no overlap
    unless one binds the exact same command string (including spacing)
]=====]--

local mp = require 'mp'
local msg = require 'mp.msg'

--keeps track of the current position for a specific cycle
local iterators = {}

--main function to identify and run the cycles
local function main(...)
    local commands = {...}

    --to identify the specific cycle we'll concatenate all the strings together to use
    --as our table key
    local str = ""
    for _,v in ipairs(commands) do
        str = str .. v .. " | "
    end
    msg.debug('recieved: ' .. str)

    --if there is no iterator saved for the current string, then creates a new one
    if iterators[str] == nil then
        msg.verbose('unknown cycle, creating iterator')
        iterators[str]= 0
    end

    --moves the iterator forward
    iterators[str] = iterators[str] + 1
    if iterators[str] > #commands then
        msg.verbose('reached end of cycle, wrapping back to start')
        iterators[str] = 1
    end

    local i = iterators[str]

    --runs each command in the cycle
    --mp.command should run the commands exactly as if they were entered in input.conf.
    --This should provide universal support for all input.conf command syntax
    msg.verbose('sending command: ' .. commands[i])
    mp.command(commands[i])
end

mp.register_script_message('cycle-commands', main)
