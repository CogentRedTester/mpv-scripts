My modified Lua scripts:

# change-refresh #

Uses nircmd to change the resolution and refresh rate of the monitor to match the playing video.

Saves the original monitor resolution and reverts changes on exit and when hotkey is pressed.

Full description in file.

# cycle-profile #
Cycles through a list of profiles sent via a script message and prints the profile-desc to the OSD. More details at the top of the file

# editions-notification #
Prints a message on the OSD if editions are found in the file, and temporarily switches the osd-playing-message to the editions-list property when switching. This makes it easier to tell the number and names of the editions.

# autoload #
Exactly the same as the script available here: https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua

However, instead of loading automatically it only loads when a keybind is pressed (Ctrl+f8 by default)