Here are some tools around video processing

# extract_titles_from

Processes DVD rips and extracts every single title into a separate video file.
And this is done with the command line interface of Handbrake.
It has been developed under Linux, and is working perfectly fine there.

What you still need to do is to rename the generated files to a useful name.
Also, the folder requires some cleanup afterwards.

The target name will be automatically generated. If it already exists,
processing for this will be skipped.
If you want to reprocess it, then you need to remove the target file manually.

It it intended for separating episodes of TV series into single files with
following features/requirements:

- Execution without GUI
- Automatically process all titles in an ISO file or `VIDEO_TS` folder
- Extract all audio tracks based on language list as they are
- Video will be re-encoded
- Extract all subtitle tracks based on language list
- Do as much as possible automatically
- Use an existing established software for the video processing

If you know, what you are doing, you can tweak the options used for Handbrake

## extract_titles_from_iso.sh

This is a bash script to take all ISO files in current folder, and extract all
titles into separate files. Also some optimizing options are provided.

As after some time, I've optimized options, but they are not included in this
script yet.

## extract_titles_from_vobs.sh

This is a copy from extract_titles_from_iso.sh but with some changes:

1. In current folder must reside all to process subfolders with proper name,
where the `VIDEO_TS` folders are underneath.
2. the folders in current folder will be used for new video name
3. removed some optimization options
4. added some options to better process desired languages for audio and subtitles
