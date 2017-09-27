Here are some tools around video processing

# extract_titles_from

Simple scripts for mass video processing. No arguments are required.

Intention is for mass processing of TV Series DVDs.

## extract_titles_from_iso.sh

This is a bash script to take all ISO files in current folder, and extract all
titles into separate files. Also some optimizing options are provided.

## extract_titles_from_vobs.sh

This is a copy from extract_titles_from_iso.sh but with some changes:

1. In current folder must reside all to process subfolders with proper name,
where the `VIDEO_TS` folders are underneath.
2. the folders in current folder will be used for new video name
3. removed some optimization options
4. added some options to better process desired languages for audio and subtitles
