--shuffles the playlist and moves the currently playing file to the start of the playlist

function main()
    mp.command('playlist-shuffle')

    local pos = mp.get_property_number('playlist-pos')

    mp.commandv('playlist-move', pos, 0)
    mp.commandv('show-text', 'playlist shuffled')
end

mp.register_script_message('playlist-shuffle', main)