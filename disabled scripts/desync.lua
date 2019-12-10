--detects when shaders are activated or deactivated and does a short seek to prevent AV desyncs
--may not be needed now that mpv does not fallback to audio mode on large desyncs

msg =  require 'mp.msg'

msg.verbose('desync loaded')

function shaders()
    msg.verbose('shaders changed')
    msg.verbose(mp.get_property('options/glsl-shaders'))
    mp.command('seek -1')
end

mp.observe_property('options/glsl-shaders', nil, shaders)