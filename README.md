# extract_titles_from_iso.sh
Processes ISO files (DVD rips) and extracts every single title into a separate mp4 file.
And this is done with the command line interface to Handbrake.
It has been developed under Linux, and is working perfectly fine there.

What you still need to do is to rename the generated files to a useful name.
Also, the folder requires some cleanup afterwards.

The target name will be automatically generated. If it already exists, processing for this will be skipped.
If you want to reprocess it, then you need to remove the target file manually.

It was intended for separating episodes of TV series into single files with following features/requirements:
- Execution without GUI
- Automatically process all titles in an ISO file
- Extract all audio tracks per title as they are
- Video will be encoded in h264 in very good quality
- Do as much as possible automatically
- Use an existing established software for the video processing

If you know, what you are doing, you can tweak the options used for Handbrake

# optimize_mkv.sh
Look for files with "mkv" extension in current folder.
Or give a list of files.
Use ffmpeg to convert it into a more optimized (eg. H264) codec.
All audio tracks are copied as they are.
Only video will be optimized

There are two paramters to control the output (size):
- CRF: compression factor (default 23)
- VCODEC: codec for video (default libx265) 
Change the script or set those environment variables to a different value
