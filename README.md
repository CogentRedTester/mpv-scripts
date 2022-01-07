# My Lua scripts

A collection of scripts I have written for mpv over the years. Small ones are kept in this repository, larger ones have their own.
Please keep in mind that not all of these scripts are maintained, and some of these were experiments which didn't pan out.
Nevertheless, feel free to submit issues if something breaks, and if you have any interesting script ideas feel free to make a
suggestion in the discussions tab.

## after-playback

Sends commands to nircmd (windows only) on playback finish. Commands include sleep, hibernate, shutdown, lock. Full list is in the file

## [change-refresh](https://github.com/CogentRedTester/mpv-changerefresh)

Uses nircmd (windows only) to change the resolution and refresh rate of the monitor to match the playing video.
Saves the original monitor resolution and reverts changes on exit and when hotkey is pressed.
Full description in file.

## [chapter-list](https://github.com/CogentRedTester/mpv-scroll-list/blob/master/examples/chapter-list.lua)

Creates an scrollable list of chapters to allow more granular chapter selection.
Requires [scroll-list](#scroll-list)

## command-timeout

Sends an input command after a specified delay

## [coverart](https://github.com/CogentRedTester/mpv-coverart)

Automatically scans the directory of the currently loaded file and loads any valid cover art into mpv as additional video tracks.
Has options for selecting what file names and types are considered valid.

## cycle-commands

Cycles through a series of commands on a keypress. Each iteration of the cycle can contain as many commands as one wants. Syntax details are at the top of the file.

## cycle-profile

Cycles through a list of profiles sent via a script message and prints the profile-desc to the OSD. More details at the top of the file

## delay-command

An extremely simple script which executes an input.conf command only after a set delay.

## display-profiles

Automatically applies profiles when the mpv window is moved to a new display

## [dvd-browser](https://github.com/CogentRedTester/mpv-dvd-browser)

This script uses the `lsdvd` commandline utility to allow users to view and select titles for DVDs from directly within mpv. The browser is interractive and allows for both playing the selected title, or appending it to the playlist. It is designed to be used stand-alone, or as an addon for file-browser. It also has automatic playlist support for DVDs.

## editions-notification

Prints a message on the OSD if editions are found in the file, and temporarily switches the osd-playing-message to the editions-list property when switching. This makes it easier to tell the number and names while navigating editions.

## [file-browser](https://github.com/CogentRedTester/mpv-file-browser)

A universal no-dependency file browser that uses mpv's OSD.

## ftp-compat

Changes some options when using the ftp protocol for better user experience

## keep-session

Automatically saves the current playlist on exit and allows the user to reload it next time they boot mpv

## music-mode

Switches to a music profile when an audio file is being played and switches back when a non-audio file is played

## onedrive-hook

Automatically converts a onedrive share link into a direct path which mpv can play, Windows only.

## [open-file](https://github.com/CogentRedTester/mpv-user-input/blob/master/examples/open-file.lua)

Uses [mpv-user-input](#user-input) to create an open file dialogue box.

## ordered-chapters-playlist

A script to point the player towards an ordered chapters playlist for devices which don't have direct access to their file systems.

## pause-indicator

Prints a pause icon in the middle of the screen when mpv is paused

## playlist-shuffle

shuffles the playlist and moves the current file to the start of the playlist

## profile-command

Parses a script-opt and sends it as a command. Allows input commands to be sent via profiles.

## [read-file](https://github.com/CogentRedTester/mpv-read-file)

An API that provides scripts with a universal interface for reading text files.
This allows scripts to easily read network files over a variety of protocols.

## save-playlist

A script for saving m3u playlists based on mpvs current internal playlist.
Users can set the name and directory to save the file in the initial script message,
or can enter custom strings in the osd.

This script requires [mpv-user-input](#user-input).

## [scroll-list](https://github.com/CogentRedTester/mpv-scroll-list)

A lua module to easily allow the creation of interactive scrollable lists.

## [search-page](https://github.com/CogentRedTester/mpv-search-page)

Allows in-player searching of keybinds, commands, properties, and options, and displays the results on the OSD.

Requires [scroll-list](#scroll-list) and [user-input](#user-input).

## [segment-linking](https://github.com/CogentRedTester/mpv-segment-linking)

Implements support for Matroska [hard segment linking](https://www.ietf.org/archive/id/draft-ietf-cellar-matroska-06.html#name-hard-linking).
This is **not** the same as [ordered chapters](https://www.ietf.org/archive/id/draft-ietf-cellar-matroska-06.html#name-medium-linking), which mpv already supports natively.

## show-errors

Prints error messages onto the OSD

## [sub-select](https://github.com/CogentRedTester/mpv-sub-select)

Allows you to configure advanced subtitle track selection based on
the current audio track and the names and language of the subtitle tracks.

## syncplay-compat

Changes some settings to work well with [Syncplay](https://syncplay.pl/). Currently designed to provide support for local playlists.

## temp-profiles

Allows you to apply a profile with a timeout, after which another profile is called to revert the changes. Works well with osc layout changes.

## [user-input](https://github.com/CogentRedTester/mpv-user-input)

An API to allow scripts to request text input from the user over the OSD.
The script is built around a modified version of mpv's console.lua, so supports almost all the same keybinds.

## vars

This script allows users to set custom variables which can be used in commands and profiles.

## youtube-search

A script that allows users to search and open youtube results from within mpv.
Requires [scroll-list](#scroll-list), [user-input](#user-input), curl, and a youtube API key.
