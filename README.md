VidCutMerger - Cutting video files and merging clips  with ffmpeg
-----------------------------------------------------------------

This simple script cuts a video file according to the cutting points stored in a text file.
Each line in the text file holds the starting and ending point of a clip to be cut.
The format of the line is
	[[h:]m:]s [[h:]m:]s
where h, m, and s are single or two-digit numbers (including zero padded numbers) denoting hours, minutes, and seconds respectively. The starting and ending points are separated by a single space. The format
	hh:mm:ss hh:mm:ss
is also acceptable as a subset of the general format.

Warning. No extra characters are allowed after the ending point.


USAGE

	vidcutmerger -i InputVideoFile [-o OutputBaseName] [-m] [-f fmt] [-d] [-h]

- InputVideoFile is a video-format file acceptable by ffmpeg
- OutputBaseName is the base name of output clips, to which consecutive numbers are added and the original extension of the InputVideoFile
- "m" commands the script to merge clips into OutputBaseName.fmt
- "f" denotes the format (fmt) of the output file to merge
- "d" tells the script to print some information about variables and operation. When "d" is not used, there will be no messages.
- "h" stands for help

See man pages (man vidcutmerger) for full description including more options.


DEPENDENCIES

- ffmpeg (Commands:  ffmpeg, ffprobe)
