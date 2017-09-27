# other_tools

Subfolder for other small independent tools around video processing.

# optimize_mkv.sh

Look for files with "mkv" extension in current folder.
Or give a list of files.
Use ffmpeg to convert it into a more optimized (eg. H264) codec.
All audio tracks are copied as they are.
Only video will be optimized.

There are two paramters to control the output (quality and size):
- CRF: compression factor (default 23)
- VCODEC: codec for video (default libx265)

Change the script or set those environment variables to a different value

# optimize_mkv.py

This is a rewrite of optimize_mkv.sh in python with same features plus this
intended additional functionality:

- Using a sqlite3 database to keep configuration
  - Setup watch folders, so one invocation can scan folders if new files
    arrived
  - Keeping track and statistics of processed files
  - Configuration
- Still single script
