--[=====[
    An extremely basic script to allow people to send input command via profiles
    available at: https://github.com/CogentRedTester/mpv-scripts

    The script reads the string entered into the script-opt list and runs the string as a command.
    Syntax is exactly the same as in input.conf. The ideal way to set these options inside profiles is to
    use script-opts append.

    Arguments with spaces or special characters require double quote encapsulation.
    Multiple commands can be sent using a semicolon.

    Examples:

        [profile]
        script-opts-append=profile_command-cmd= show-text "showing this text" 30

        [profile2]
        script-opts-append=profile_command-cmd= set vid 0 ; show-text "disabling video"
]=====]--

local o = {
    cmd = ""
}

local opt = require 'mp.options'
opt.read_options(o, 'profile_command', function()
    if o.cmd == "" then return end
    mp.command(o.cmd)

    --resets the property so that the same command can be sent multiple times in a row
    mp.commandv('change-list', 'script-opts', 'append', 'profile_command-cmd=')
end)