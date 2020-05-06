--an extremely basic script to allow people to send input command via profiles
--currently it can only send one at a time

local o = {
    cmd = ""
}

local opt = require 'mp.options'
local utils = require 'mp.utils'

opt.read_options(o, 'profile_command', function()
    if o.cmd == "" then return end

    local command = utils.parse_json(o.cmd)
    mp.command_native(command)
end)