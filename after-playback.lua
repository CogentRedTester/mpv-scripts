--[[
    Runs the specified action when mpv shutsdown using the nircmd command line tool for windows
    available at: https://github.com/CogentRedTester/mpv-scripts

    By default the command will only be sent if mpv finishes playing the current file before shutting down,
    this means quitting the player manually will not trigger the action, unless the `always_run_on_shutdown`
    option is set to yes.

    This means that you need to set keep-open and loop to `no` for the script to do anything.


    Commands are set with script messages:

        script-message after-playback [command] {flag}

    Valid commands are:
        nothing     -   do nothing, the default, and is used to disable prior commands
        lock        -   locks the computer so that it needs a password to reopen
        sleep       -   puts the computer to sleep
        logoff      -   logs the current user off
        hibernate   -   activates hibernate mode
        displayoff  -   turns off the displays (computer is still running like normal)
        shutdown    -   shuts down computer after 60 seconds
        reboot      -   reboots the computer after 60 seconds

    Valid flags are:
        osd         -   displays osd message (when setting the command, not when it is executed) (default)
        no_osd      -   does not display osd message (when setting the command, not when it is executed)

    There is time to disable the shutdown and reboot commands by sending a command to nircmd directly through cmd/powershell.
    This must be sent within 60 seconds of the commands being sent. The command is "nircmd abortshutdown"

    The default command can be set with script-opts:
        script-opts=afterplayback-default=[command]

    See the options table for more options
]]--

msg = require 'mp.msg'
utils = require 'mp.utils'
opt = require 'mp.options'

--OPTIONS--
local o = {
    --default action
    default = "nothing",

    --runs the action every time the player shuts down
    --normally actions are only run when playback ends naturally
    always_run_on_shutdown = false,

    --set whether to output status messages to the OSD
    osd_output = true
}


local commands = {}
local current_action = "nothing"
local active = false

function osd_message(message)
    if o.osd_output then
        mp.osd_message(message, 2)
    end
end

--sets the list of commands to send to nircmd
function set_action(action, flag)
    msg.debug('flag = "' .. tostring(flag) .. '"')
    
    --disables or enables the osd for the duration of the function if the flags are set
    local osd = o.osd_output
    if flag == 'osd' then
        o.osd_output = true
    elseif flag == 'no_osd' then
        o.osd_output = false
    end

    if active or action ~= "nothing" then
        msg.info('after playback: ' .. action)
        osd_message('after playback: ' .. action)
    end

    commands = {'nircmd'}
    active = true

    if action == 'sleep' then
        commands[2] = "standby"

    elseif action == "logoff" then
        commands[2] = "exitwin"
        commands[3] = "logoff"

    elseif action == "hibernate" then
        commands[2] = "hibernate"

    elseif action == "shutdown" then
        commands[2] = "initshutdown"
        commands[3] = "60 seconds before system shuts down"
        commands[4] = "60"

    elseif action == "reboot" then
        commands[2] = "initshutdown"
        commands[3] = "60 seconds before system reboots"
        commands[4] = "60"
        commands[5] = "reboot"

    elseif action == "lock" then
        commands[2] = "lockws"

    elseif action == "displayoff" then
        commands[2] = "monitor"
        commands[3] = "off"

    elseif action == "nothing" then
        active = false

    else
        msg.warn('unknown action "' .. action .. '"')
        osd_message('after-playback: unknown action')
        action = current_action
    end

    o.osd_output = osd
    current_action = action
end

--runs the saved action if the script is activated
function run_action()
    if active == false then return end

    msg.info('executing command "' .. current_action .. '"')

    mp.command_native({
        name = 'subprocess',
        playback_only = false,
        args = commands
    })
end

--runs when the file is closed.
--runs the command if the reason for the close was eof.
--this is necessary because the eof property is set to nil immediately,
--so it can't return true for the above function. We don't want to run
--the action when the user quits themselves, so we need an extra check
local reason = ""
function recordEOF(event)
    if not active then return end;
    msg.debug('saving reason for end-file: "' .. event.reason .. '"')
    reason = event.reason
end

--runs the saved action if the file was closed naturally
function shutdown()
    if not active then return end;
    msg.debug('shutting down mpv, testing for shutdown reason')
    if reason == "eof" or o.always_run_on_shutdown
    then
        msg.debug('shutdown caused by eof, running action')
        run_action()
    end
end

--sets the default option on mpv player launch
opt.read_options(o, 'afterplayback')
set_action(o.default)
msg.verbose('default action after playback is "' .. current_action .. '"')


mp.register_event('end-file', recordEOF)
mp.register_event('shutdown', shutdown)

mp.register_script_message('after-playback', set_action)