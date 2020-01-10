--[[
    Runs the specified action on playback finish using the nircmd command line tool for windows
    Only runs when playback finished, quitting or otherwise stopping playback will not trigger the command

    Commands are set with script messages:
        
        script-message after-playback [command] {flag}

    Valid commands are:
        nothing     -   do nothing, the default, and is used to disable prior commands
        quit        -   quit the player, this is an alternative to keep-open=no (use this if you don't want to close the player and send a shutdown command at the same time)
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

    There is time to disable the shutdown and reboot commands by sending a script message:
            script-message abort-shutdown
    This must be sent within 60 seconds of eof being reached. If the player has already closed then the only
    way to abort is to reopen mpv player and send the message, or to use the command "nircmd abortshutdown" in the terminal

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

    --runs the action every time the player quits
    --normally actions are only run when playback ends naturally
    run_on_quit = false,

    --set whether to output status messages to the OSD by default
    osd_output = true
}


local commands = {}
local current_action
local active = false

function osd_message(message)
    if o.osd_output then
        mp.osd_message(message)
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

    elseif action == 'quit' then
        commands = {"quit"}

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

    osd_message('executing command  ' .. current_action)
    msg.info('executing command "' .. current_action .. '"')
    mp.command_native({
        name = 'subprocess',
        playback_only = false,
        args = commands
    })
end

--sends the abort command to nircmd to disable the shutdown and reboot commands
function abort_shutdown()
    msg.info('sending abort for shutdown and reboot commands')
    osd_message('aborting shutdown/reboot')

    mp.command_native({
        name = 'subprocess',
        playback_only = false,
        args = {"nircmd", "abortshutdown"}
    })
end

--runs when the files eof property has changed
--for some reason this is triggered after every seek?
function eof()
    local finished = mp.get_property_bool('eof-reached')
    msg.debug('eof = ' .. tostring(finished))
    
    if finished then
        run_action()
    end
end

--runs when the file is closed.
--runs the command if the reason for the close was eof.
--this is necessary because the eof property is set to nil immediately,
--so it can't return true for the above function. We don't want to run
--the action when the user quits themselves, so we need an extra check
function end_file(event)
    msg.debug('event: ' .. utils.to_string(event))

    local reason = ""
    if event.event == "end-file" then
        msg.debug('saving reason for end-file: "' .. event.reason .. '"')
        reason = event.reason
        return
    end

    --since switching files in a playlist seems to have the same 
    if reason == "eof" or o.run_on_quit
    then
        run_action()
    end
end

function shutdown(event)
    msg.verbose(utils.to_string(event))
end

--sets the default option on mpv player launch
opt.read_options(o, 'afterplayback')
set_action(o.default)

--runs eof functions when status changes
mp.observe_property('eof-reached', nil, eof)
mp.register_event('end-file', end_file)
mp.register_event('shutdown', end_file)

mp.register_script_message('after-playback', set_action)

mp.register_script_message('abort-shutdown', abort_shutdown)