My modified Lua scripts:

# change-refresh #

Uses nircmd (windows only) to change the resolution and refresh rate of the monitor to match the playing video.

Saves the original monitor resolution and reverts changes on exit and when hotkey is pressed.

Full description in file.

# coverart #
Automatically scans the directory of the currently loaded file and loads any valid cover art into mpv as additional video tracks.
Has options for selecting what file names and types are considered valid.

# cycle-profile #
Cycles through a list of profiles sent via a script message and prints the profile-desc to the OSD. More details at the top of the file

# editions-notification #
Prints a message on the OSD if editions are found in the file, and temporarily switches the osd-playing-message to the editions-list property when switching. This makes it easier to tell the number and names of the editions.

# music-mode #
Switches to a music profile when an audio file is being played and forces an update to the osc to allow for separate layouts for music, requires my modified osc.lua

# osc #
Identical to the script here: https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua

However, I have added an extra function and script message to allow for changing the layout during runtime using profiles

# playlist-shuffle #
shuffles the playlist and moves the current file to the start of the playlist

# autoload #
Exactly the same as the script available here: https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua

However, instead of loading automatically it only loads when a keybind is pressed (Ctrl+f8 by default)