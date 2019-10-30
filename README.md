# autospeedwin

######Lua script for [mpv](https://mpv.io/) to adjust monitor refresh rate and video speed for almost 1:1 playback.

--------------

#####Notes:

* This script is for the Microsoft Windows operating systems, [see here for the *nix version](https://github.com/kevinlekiller/mpv_scripts/tree/master/autospeed).

* Can use (recommended) [nircmd](http://www.nirsoft.net/utils/nircmd.html) To set your monitor refresh rate closer to the video playback speed.

* By default mpv will adjust the audio pitch to match the speed difference. You can read the [mpv manual](http://mpv.io/manual/master/#options-audio-pitch-correction) for more information on this.

* Works better with mpv's [`--video-sync=display-resample`](https://mpv.io/manual/master/#options-video-sync)  
If using mpv's [`--video-sync=display-resample`](https://mpv.io/manual/master/#options-video-sync), do not use `autospeed-speed=true`  
If you have issues with mpv's [`--video-sync=display-resample`](https://mpv.io/manual/master/#options-video-sync), you can use `--video-sync=audio` and `autospeed-speed=true`, which still produces acceptable results.  

--------------

#####Basic Description:

Optionally changes the monitor refresh rate to be closer to the video fps, then sets
the speed of the video to be closer to the monitor refresh rate.

Lower resource usage than using interpolation.

--------------

#####Script options:

The script can read options from mpv's [--script-opts](http://mpv.io/manual/master/#options-script-opts) option.

Valid options (and examples):

    autospeed-nircmd=false
        true/false - Use nircmd to change the refresh rate of your monitor.
        nircmd will be used to change the refresh rate of your monitor based on options listed below.
    autospeed-speed=false
        Default: false
        true/false - Adjust speed of the video?
        If set to true, the mpv speed setting will be changed based on the video
        fps and display refresh rate.
        Do not use this with mpv's --video-sync=display-resample
    autospeed-nircmdc="nircmdc"
        String - Path to nircmdc executable file.
        If not set, nircmdc will be searched in Windows PATH variable.
        If you set this "" or "nircmdc", Windows will look in your PATH for nircmdc,
        otherwise you can specify a path, for example "c:\programs\nircmdc.exe"
    autospeed-monitor=0
        Number - Which monitor (display) to set the refresh rate on.
        This will be sent to nircmd when setting the refresh rate.
    autospeed-dwidth=1920
        Number - Display width.
        This will be sent to nircmd when setting the refresh rate.
    autospeed-dheight=1080
        Number - Display height.
        This will be sent to nircmd when setting the refresh rate.
    autospeed-bdepth=32
        Number - Display bit depth. 32 is usually the default.
        This will be sent to nircmd when setting the refresh rate.
    autospeed-rates="60"
        String - String of refresh rates your monitor supports and you want
            to use, separated by semicolons. Nircmd seems to prefer rounded
            numbers, 72 instead of 71.92 for example.
        This is the list of refresh rates you want autospeed to use when it changes your monitor refresh rate.
        Examples: autospeed-rates="60" | autospeed-rates="50;60;72"
        Note: If you want a rate to be prefered over another, for example the video is 24hz
        and your rates are "100;120;144", but you want 144hz instead of 120hz for 24fps videos, change the
        order to autospeed-rates="100;144;120", then 144hz will take precendence over 120hz.
    autospeed-exitrate=60
        Number - Which refresh rate to set when exiting mpv. Set to 0 to ignore.
        When mpv exits, if you want your monitor to go back to a specific refresh rate.
    autospeed-minspeed=0.9
        Number - Minimum allowable speed to play video at.
        Does not change mpv's speed setting if the calculated speed is lower than this.
        This is to prevent the video looking like it is in slow motion.
        A value of 0.9 allows playing the video at minimum, 10% slower.
    autospeed-maxspeed=1.1
        Number - Maximum allowable speed to play video at.
        Does not change mpv's speed setting if the calculated speed is higher than this.
        This is to prevent the video looking like it is in fast forward.
        A value of 1.1 allows playing the video at maximum, 10% faster.
    autospeed-osd=false
        true/false - Enable OSD.
        This enables/disables the other autospeed-osd settings.
    autospeed-osdtime=10
        Number - How many seconds the OSD will be shown.
    autospeed-osdkey=y
        Key to press to show the OSD.
        This follows the same standard as mpv's input.conf for keybindgs.
        Pressing this key will display autospeed information on mpv's OSD.
    autospeed-estfps=false
        true/false - Calculate/change speed if a video has a variable fps
                     at the cost of higher CPU usage.
        If a video has a variable frame rate (fps),
        calculate / set the mpv speed based on the current video frame rate.
        This option will do nothing for most videos because, only few of them have variable fps.
        For example, most (all?) bluray videos have variable frame rates.
        Since the speed calulation must be done every time the video fps changes,
        this increases CPU load slightly.
    autospeed-spause=4
        Default: false
        true/false - Pause video while switching display modes.
                     true:  This will pause the video before and after switching the mode.
                     false: Disables this option.
        Number     - This enables the pause like true and sleeps for this amount of seconds.
                     If bigger than 0: After switching the mode, we will wait this amount
                     of seconds before unpausing the video.
                     If set to 0:      It disables the option, like false.
        Before switching the display mode (refresh rate), pause the video, unpause after
        it is switched. This can be used if you don't want to miss
        some of the video while your display is blank (my display is blank for ~5 seconds
        while switching modes).
    
    Examples:
        Setting the options at the command line:
            mpv file.mkv --script-opts=autospeed-speed=true,autospeed-estfps=true,autospeed-minspeed=0.8
        Setting the options in %APPDATA%\mpv\mpv.conf:
            script-opts=autospeed-nircmd=true,autospeed-speed=false,autospeed-nircmdc="nircmdc",autospeed-monitor=0,autospeed-dwidth=1920,autospeed-dheight=1080,autospeed-bdepth=32,autospeed-rates="60;72",autospeed-exitrate=60,autospeed-minspeed=0.9,autospeed-maxspeed=1.1,autospeed-osd=true,autospeed-osdtime=10,autospeed-osdkey=y,autospeed-estfps=false,autospeed-spause=4

--------------

#####Installation:

Put the file inside the mpv\scripts folder, see the [mpv man page](https://github.com/mpv-player/mpv/blob/master/DOCS/man/mpv.rst#files) for the correct path, should be `%APPDATA%\mpv\scripts\`.


Direct download link:  
[autospeedwin.lua](https://raw.githubusercontent.com/kevinlekiller/mpv_scripts/master/autospeedwin/autospeedwin.lua)  

--------------

#####Examples:

* >
The display supports 72hz.  
The video is 23.97602397602398fps.  
The display is currently 60hz.  
The display is set to 72hz.  
The mpv speed setting is set to 1.001.  
The video now plays at 24fps (23.97602397602398fps * 1.001 = 24).  
Every frame is repeated 3 times, so 1:1 playback.

* >  
The display supports 50hz.  
The video is 24.95fps.  
The display is currently 60hz.  
The display is set to 50hz.  
The mpv speed setting is set to 1.002004008016032.  
The video now plays at 25fps.  

* >  
The display supports 60hz.  
The display is currently 144hz.  
The video is 60fps.  
The display is set to 60hz.

--------------

#####License:

GPL V2  
See [LICENSE](https://github.com/kevinlekiller/mpv_scripts/blob/master/LICENSE)
