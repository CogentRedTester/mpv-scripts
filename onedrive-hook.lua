--detects when a onedrive link is loaded and converts it to an absolute path to play the file
--uses powershell, so it only works on windows. Though if someone is using the cross-platform
--version of powershell, they may just need to change the first arguement from 'powershell' to 'pwsh'

local mp = require 'mp'
local msg = require 'mp.msg'

function fix_onedrive_link()
    local path = mp.get_property('stream-open-filename', '')
    if path:find("https://1drv.ms") ~= 1 then
        return
    end
    msg.info('onedrive link detected, expanding to create direct url')
    local command = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = {
            'powershell',
            '-command',
            '([System.Net.HttpWebRequest]::Create("' .. path .. '")).GetResponse().ResponseUri.AbsoluteUri'
        }
    })

    path = command.stdout
    path = path:gsub('redir%?', 'download%?')
    msg.verbose('expanded onedrive url: ' .. path)
    mp.set_property('stream-open-filename', path)
end

mp.add_hook('on_load', 50, fix_onedrive_link)