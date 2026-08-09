#!/bin/bash

# ============================================================================
# g_compress_video2.sh - Video compression script (H.265/HEVC)
# ============================================================================
#
# Changes compared to g_compress_video.sh:
#
# 1. TWO AUDIO TRACKS: Both German and English audio are kept as separate
#    streams, each with its own codec and quality settings. German is always
#    the default track.
#
# 2. SINGLE UNLABELED AUDIO: If there is only one audio track and it has no
#    language tag (or "und"), it is automatically labeled as "german".
#
# 3. SUBTITLES PRESERVED: Unlike the old script which only kept forced
#    German subtitles and burned them into the video, this script preserves
#    ALL subtitle types (including image-based DVD subtitles) as separate
#    soft-sub tracks with proper language tags.
#
# 4. MKV OUTPUT FORMAT: Uses Matroska instead of MP4, because MP4 cannot
#    store image-based subtitle streams.
#
# 5. CLEAN METADATA: Removes unnecessary metadata like handler_name,
#    encoder version, and chapter markers from the output.
#
# 6. RELIABLE ALREADY-PROCESSED DETECTION: Instead of a fragile line-count
#    heuristic, checks for HEVC video + HE-AAC/AC3 audio only + resolution
#    <= 1920 + no chapters.
#
# 7. ROBUST ERROR HANDLING: Validates output file existence and minimum size
#    (10 MB). Retries up to 3 times on failure. Temp files are always cleaned
#    up via trap on any exit.
#
# 8. OUTPUT VALIDATION: Checks that the output is actually HEVC and duration
#    also larger than 10 MB before replacing the original. 
#    Keeps the original on failure.
#
# 9. PRESERVE FILE ATTRIBUTES: Uses "cat >" instead of "mv" to replace the
#    original file, preserving permissions, ownership, and inode. Touch
#    updates the modification time while ctime stays unchanged.
#
# 10. CLEANUP ON ABORT: Trap automatically removes all temp files and
#     progress markers on any interrupt or error.
#
# 11. 1080P SUPPORT: Supports up to 1920x1080 target resolution (old script
#     was limited to 720p/960p).
#
# 12. FIXED md5sum WAIT: Uses "while" loop (was "until" which had inverted
#     logic and could hang).
#
# 13. CLI OPTIONS: Script uses getopts: -f <file> (required), -r <host>
#     (optional remote docker host), -s (optional stereo downmix).
#
# 14. OPTIONAL STEREO DOWNMIX: With -s, 5.1/6.1/7.1 surround is downmixed
#     to stereo (HE-AACv2 48k) instead of keeping AC3 384k.
#
# ============================================================================

function g_compress_video2 {

  # get cli options
  local g_vid=""
  local g_remotedockerffmpeg=""
  local g_stereo=false
  local OPTIND=1
  while getopts "f:r:s" opt
  do
    case "$opt" in
      f) g_vid="$OPTARG" ;;
      r) g_remotedockerffmpeg="$OPTARG" ;;
      s) g_stereo=true ;;
      *) g_echo_warn "Usage: $0 -f <file> [-r <host>] [-s]"; return 1 ;;
    esac
  done

  if [ -z "$g_vid" ]
  then
    g_echo_warn "Missing required option: -f <file>"
    return 1
  fi

  # use absolute path
  g_vid=$(realpath "$g_vid")

  # begin
  g_echo_note "Starting ${FUNCNAME} $@"
  local g_viddone=""

  function g_tmp_cleanup {
    rm -f /tmp/"${g_vid_md5}".g_progressing 2>/dev/null
    rm -f "$g_tmp"/vidinfo "$g_tmp"/vidinfo_original "$g_tmp"/vidinfo51 "$g_tmp"/cmd
    rm -f "$g_viddone" "${g_viddone}-streamable" "${g_viddone}-withsubs" "${g_viddone}-raw"
    trap - INT TERM ERR
  }

  # Trap: clean up temp files and progress marker on interrupt/error
  trap 'g_tmp_cleanup; return 1' INT TERM ERR

  # Probe the input file with ffmpeg to get stream info; strip hex stream IDs for easier parsing
  ffmpeg -hide_banner -i "$g_vid" 2>&1 | grep -E '^(Input |  Duration|  Program|  Stream)' | perl -pe 's/\[0x[0-9]+\]//g' >"$g_tmp"/vidinfo
  cp "$g_tmp"/vidinfo "$g_tmp"/vidinfo_original

  # Check if the file exists and is readable
  if egrep -q "Invalid data found when processing input|No such file or directory" "$g_tmp"/vidinfo
  then
   g_echo_warn "Video $g_vid does not exist (anymore) or is corrupted."
   trap - INT TERM ERR
   return 1
  fi

  # Already-processed detection: if video is HEVC, audio is only HE-AAC/AC3, resolution <= 1920, and no chapters, skip
  if egrep -q "Stream.+Video: hevc" "$g_tmp"/vidinfo
  then
   local g_bad_audio=$(cat "$g_tmp"/vidinfo | grep ": Audio:" | egrep -v "HE-AAC|ac3" | wc -l)
   local g_vidwidth=$(cat "$g_tmp"/vidinfo | egrep "Stream.+Video:" | perl -pe 's/ /\n/g;' | egrep "[0-9]x[0-9]" | cut -d"x" -f 1 | perl -pe 's/[^0-9]//g')
   local g_has_chapters=$(cat "$g_tmp"/vidinfo | grep -c "Chapter #")
   if [ "$g_bad_audio" -eq 0 ] && [ -n "$g_vidwidth" ] && [ "$g_vidwidth" -le 1920 ] && [ "$g_has_chapters" -eq 0 ]
   then
    g_echo "Video $g_vid already processed!"
    trap - INT TERM ERR
    return 1
   fi
  fi

  # Random wait time for retry delays
  local g_wait=$(($RANDOM % 60))

  # Wait if another md5sum is running (prevents disk thrashing)
  while ps ax | grep -q "[m]d5sum"
  do
   g_echo "Another md5sum is still running - waiting 2 seconds"
   sleep 2
  done

  # Create checksum for duplicate-processing detection
  g_echo "Please wait... Creating checksum for $g_vid."
  local g_vid_md5=$(md5sum "$g_vid" | cut -d" " -f1)
  if [ -e /tmp/"$g_vid_md5".g_progressing ]
  then
   g_echo "File $g_vid seems to already be compressing"
   trap - INT TERM ERR
   return 1
  fi
  echo $$ > /tmp/"$g_vid_md5".g_progressing

  # Generate unique temp filename for intermediate files
  local g_rnd=`shuf -i 10000-65000 -n 1`
  local g_vidbasename=`basename "$g_vid"`
  g_viddone="$g_tmp/$g_vidbasename-$g_rnd-DONE.mkv"

  # Remux into a streamable MKV intermediate (all codecs pass through, MKV header is always first)
  ffmpeg -loglevel warning -stats -i "${g_vid}" -map 0:v -map 0:a -c copy -ignore_unknown -f matroska "${g_viddone}-streamable" < /dev/null 2>&1

  # Fallback: if MKV remux fails, use original file directly via symlink
  if ! [ -f "${g_viddone}-streamable" ]
  then
    g_echo_warn "Remux to intermediate file failed — using original file directly"
    ln -sf "$g_vid" "${g_viddone}-streamable"
  fi

  # Re-probe the streamable copy for accurate stream info
  ffmpeg -hide_banner -i "${g_viddone}-streamable" 2>&1 | grep -E '^(Input |  Duration|  Program|  Stream)' | perl -pe 's/\[0x[0-9]+\]//g' >"$g_tmp"/vidinfo

  cat "$g_tmp"/vidinfo

  # Move 5.1/6.1/7.1 surround lines to top so channel detection picks them up first
  cat "$g_tmp"/vidinfo | egrep "5\.1|6\.1|7\.1" >"$g_tmp"/vidinfo51
  cat "$g_tmp"/vidinfo >>"$g_tmp"/vidinfo51
  cat "$g_tmp"/vidinfo51 >"$g_tmp"/vidinfo

  # Detect video stream ID for mapping
  g_echo "Processing video $g_vid"
  local g_vidstream=`cat "$g_tmp"/vidinfo | grep Stream | grep ": Video: " | perl -pe 's/\#/:/g; s/\(/:/g; s/\[/:/g' | cut -d: -f 2,3 | head -n1`
  g_echo "Video stream is $g_vidstream"

  # Find the best German audio stream (most channels wins)
  local g_audstream_de=""
  local g_audlang_de=""
  local g_dechannels=0
  local g_max_channels_de=0
  while IFS= read -r line
  do
    if echo "$line" | egrep -q '(ger|deu)'
    then
      local stream_id=`echo "$line" | perl -pe 's/\#/:/g; s/\(/:/g; s/\[/:/g' | cut -d: -f 2,3`
      local channels=0
      echo "$line" | egrep -q '7\.1' && channels=8
      echo "$line" | egrep -q '6\.1' && channels=7
      echo "$line" | egrep -q '5\.1' && channels=6
      echo "$line" | egrep -q '5\.0' && channels=5
      echo "$line" | egrep -q '4\.0' && channels=4
      echo "$line" | egrep -q '3\.1' && channels=4
      echo "$line" | egrep -q 'stereo' && [ $channels -eq 0 ] && channels=2
      echo "$line" | egrep -q 'mono' && [ $channels -eq 0 ] && channels=1
      if [ $channels -gt $g_max_channels_de ]
      then
        g_max_channels_de=$channels
        g_audstream_de=$stream_id
        local rawlang=`echo "$line" | egrep -o '\([a-z]{3}\)' | head -1 | tr -d '()'`
        [ "$rawlang" = "deu" ] && rawlang="ger"
        g_audlang_de="$rawlang"
        g_dechannels=$channels
      fi
    fi
  done < <(cat "$g_tmp"/vidinfo | grep Stream | grep ": Audio: ")

  # Find the best English audio stream (most channels wins)
  local g_audstream_en=""
  local g_audlang_en=""
  local g_enchannels=0
  local g_max_channels_en=0
  while IFS= read -r line
  do
    if echo "$line" | egrep -q '(eng|enu)'
    then
      local stream_id=`echo "$line" | perl -pe 's/\#/:/g; s/\(/:/g; s/\[/:/g' | cut -d: -f 2,3`
      local channels=0
      echo "$line" | egrep -q '7\.1' && channels=8
      echo "$line" | egrep -q '6\.1' && channels=7
      echo "$line" | egrep -q '5\.1' && channels=6
      echo "$line" | egrep -q '5\.0' && channels=5
      echo "$line" | egrep -q '4\.0' && channels=4
      echo "$line" | egrep -q '3\.1' && channels=4
      echo "$line" | egrep -q 'stereo' && [ $channels -eq 0 ] && channels=2
      echo "$line" | egrep -q 'mono' && [ $channels -eq 0 ] && channels=1
      if [ $channels -gt $g_max_channels_en ]
      then
        g_max_channels_en=$channels
        g_audstream_en=$stream_id
        local rawlang=`echo "$line" | egrep -o '\([a-z]{3}\)' | head -1 | tr -d '()'`
        [ "$rawlang" = "enu" ] && rawlang="eng"
        g_audlang_en="$rawlang"
        g_enchannels=$channels
      fi
    fi
  done < <(cat "$g_tmp"/vidinfo | grep Stream | grep ": Audio: ")

  # Fallback: if no German audio found but English exists, use English as the (default) track
  if [ -z "$g_audstream_de" ] && [ -n "$g_audstream_en" ]
  then
    g_audstream_de="$g_audstream_en"
    g_audlang_de="$g_audlang_en"
    g_dechannels=$g_enchannels
  fi

  # Fallback: if no DE or EN audio found, use the first audio stream available
  if [ -z "$g_audstream_de" ] && [ -z "$g_audstream_en" ]
  then
   local g_audline=`cat "$g_tmp"/vidinfo | grep Stream | grep ": Audio: " | head -1`
   if [ -n "$g_audline" ]
   then
     g_audstream_de=`echo "$g_audline" | perl -pe 's/\#/:/g; s/\(/:/g; s/\[/:/g' | cut -d: -f 2,3`
     local rawlang=$(echo "$g_audline" | egrep -o '\([a-z]{3}\)' | head -1 | tr -d '()')
     # If language is tagged (not und), keep it; otherwise default to German
     if [ -n "$rawlang" ] && [ "$rawlang" != "und" ]
     then
       g_audlang_de="$rawlang"
       [ "$rawlang" = "deu" ] && g_audlang_de="ger"
       [ "$rawlang" = "enu" ] && g_audlang_de="eng"
     else
       g_audlang_de="ger"
     fi
     # Detect channel count so the track is not encoded as mono
     local channels=0
     echo "$g_audline" | egrep -q '7\.1' && channels=8
     echo "$g_audline" | egrep -q '6\.1' && channels=7
     echo "$g_audline" | egrep -q '5\.1' && channels=6
     echo "$g_audline" | egrep -q '5\.0' && channels=5
     echo "$g_audline" | egrep -q '4\.0|3\.1' && channels=4
     echo "$g_audline" | egrep -q 'stereo' && [ "$channels" -eq 0 ] && channels=2
     echo "$g_audline" | egrep -q 'mono' && [ "$channels" -eq 0 ] && channels=1
     g_dechannels=$channels
   fi
  fi

  # stereo downmix?
  if [ "$g_stereo" = true ]
  then
    g_dechannels=2
    g_enchannels=2
  fi

  # Abort if no audio stream at all
  if [ -z "$g_audstream_de" ] && [ -z "$g_audstream_en" ]
  then
   g_echo "File $g_vid seems to have no audio stream"
   g_tmp_cleanup
   return 1
  fi
  g_echo "Audio streams: DE=$g_audstream_de (${g_max_channels_de}ch / $g_audlang_de) EN=$g_audstream_en (${g_max_channels_en}ch / $g_audlang_en)"

  # Detect all subtitle streams from the original file and build mapping + language metadata
  # Skip unsupported codecs: dvb_teletext, dvb_subtitle (cannot be stored in MKV)
  local g_map_orig_subs=""
  local g_sub_count=0
  local g_sub_idx=0
  local g_sub_metadata=""
  while IFS= read -r line
  do
    if echo "$line" | grep -q ": Subtitle: "
    then
      if echo "$line" | egrep -q "dvb_teletext"
      then
        g_echo "Skipping unsupported subtitle codec in: $line"
      else
        g_map_orig_subs="$g_map_orig_subs -map 1:s:$g_sub_idx"
        g_sub_count=$((g_sub_count + 1))
        local sublang=$(echo "$line" | egrep -o '\([a-z]{3}\)' | head -1 | tr -d '()')
        [ "$sublang" = "deu" ] && sublang="ger"
        [ "$sublang" = "enu" ] && sublang="eng"
        [ -n "$sublang" ] && g_sub_metadata="$g_sub_metadata -metadata:s:s:$g_sub_idx language=$sublang"
      fi
      g_sub_idx=$((g_sub_idx + 1))
    fi
  done < "$g_tmp"/vidinfo_original
  g_echo "Found $g_sub_count subtitle stream(s) to preserve"

  # Get source video width and overall bitrate for encoding decisions
  local g_vidwidth=`cat "$g_tmp"/vidinfo | egrep "Stream.+Video" | perl -pe 's/ /\n/g;' | egrep "[0-9]x[0-9]" | cut -d"x" -f 1 | perl -pe 's/[^0-9]//g'`
   
  local g_vidmaxrate=$(ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of csv=p=0 "$g_vid" 2>/dev/null)
  [ -n "$g_vidmaxrate" ] && g_vidmaxrate=$(( g_vidmaxrate / 1000 ))
  # MKV/VBR-Streams speichern keine Bitrate -> aus Dateigröße und Dauer ableiten
  if [ -z "$g_vidmaxrate" ]
  then
    local g_vid_dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$g_vid" 2>/dev/null)
    local g_vid_size=$(stat -c%s "$g_vid" 2>/dev/null)
    if [ -n "$g_vid_dur" ] && [ -n "$g_vid_size" ]
    then
      g_vidmaxrate=$(( g_vid_size * 8 / ${g_vid_dur%.*} / 1000 ))
    fi
  fi

  if [ -z $g_vidwidth ]
  then
   g_echo_warn "Could not determine resolution of video $g_vid."
   g_tmp_cleanup
   return 1
  fi
  if [ -z $g_vidmaxrate ]
  then
   g_echo "Could not determine max bitrate of video $g_vid. - Assuming 3600 kb/s"
   g_vidmaxrate=3600
  fi
  g_echo "Original bitrate $g_vidmaxrate kb/s"

  # Determine target bitrate based on source width (smaller sources need less)
  [ "$g_vidwidth" -lt "420" ] && g_vidmaxratenew="900"
  [ "$g_vidwidth" -ge "420" ] && g_vidmaxratenew="1200"
  [ "$g_vidwidth" -ge "640" ] && g_vidmaxratenew="1800"
  [ "$g_vidwidth" -ge "911" ] && g_vidmaxratenew="3600"
  [ "$g_vidwidth" -ge "1250" ] && g_vidmaxratenew="4500"
  [ "$g_vidwidth" -gt "1920" ] && g_vidmaxratenew="7000"

  # Never exceed the original bitrate
  [ $g_vidmaxrate -lt $g_vidmaxratenew ] && g_vidmaxratenew=$g_vidmaxrate

  ## Build scale filter for video
  #local g_vidscale="scale=$g_vidwidthnew:-2"
  #g_echo "Target: New width ${g_vidwidthnew} @ max ${g_vidmaxratenew} kb/s — CRF 25, 10-bit"

  ## Build scale filter: fit within 1080p, never upscale, keep aspect ratio
  #local g_vidscale="scale=1920:1080:force_original_aspect_ratio=decrease:force_divisible_by=2"
  #g_echo "Target: max 1080p (no upscaling) @ max ${g_vidmaxratenew} kb/s — CRF 25, 10-bit"

  # Determine target dimensions: never upscale, cap at 1920x1080, keep aspect ratio
  local g_vidheight=`cat "$g_tmp"/vidinfo | egrep "Stream.+Video" | perl -pe 's/ /\n/g;' | egrep "[0-9]x[0-9]" | cut -d"x" -f 2 | perl -pe 's/[^0-9]//g'`
  local g_sw=$g_vidwidth
  local g_sh=$g_vidheight
  if [ -n "$g_sh" ]
  then
    if [ "$g_vidwidth" -gt 1920 ] || [ "$g_vidheight" -gt 1080 ]
    then
      # scale factor to fit within 1920x1080 (larger dimension wins)
      local g_factor=$(( g_vidwidth * 1000 / 1920 ))
      local g_factor2=$(( g_vidheight * 1000 / 1080 ))
      [ $g_factor2 -gt $g_factor ] && g_factor=$g_factor2
      g_sw=$(( g_vidwidth * 1000 / g_factor / 2 * 2 ))
      g_sh=$(( g_vidheight * 1000 / g_factor / 2 * 2 ))
    fi
  fi
  local g_vidscale="scale=${g_sw}:${g_sh}:flags=lanczos"
  g_echo "Target: ${g_sw}x${g_sh} (max 1080p, no upscaling) @ max ${g_vidmaxratenew} kb/s — CRF 25, 10-bit"

  # Build per-stream audio codec options based on channel count
  # 5.1+ -> AC3 384k, stereo -> HE-AACv2 48k, mono -> HE-AAC 24k
  local g_audio_codec_opts=""
  local g_audio_stream_idx=0

  if [ "$g_dechannels" -ge 6 ]
  then
    g_audio_codec_opts="-c:a:$g_audio_stream_idx ac3 -b:a:$g_audio_stream_idx 384k"
  elif [ "$g_dechannels" -ge 2 ]
  then
    g_audio_codec_opts="-c:a:$g_audio_stream_idx libfdk_aac -profile:a:$g_audio_stream_idx aac_he_v2 -b:a:$g_audio_stream_idx 48k -ac:a:$g_audio_stream_idx 2"
  else
    g_audio_codec_opts="-c:a:$g_audio_stream_idx libfdk_aac -profile:a:$g_audio_stream_idx aac_he -b:a:$g_audio_stream_idx 24k -ac:a:$g_audio_stream_idx 1"
  fi
  g_audio_stream_idx=$((g_audio_stream_idx + 1))

  # Same for English audio stream if present and separate from DE
  if [ -n "$g_audstream_en" ] && [ "$g_audstream_en" != "$g_audstream_de" ]
  then
    if [ "$g_enchannels" -ge 6 ]
    then
      g_audio_codec_opts="$g_audio_codec_opts -c:a:$g_audio_stream_idx ac3 -b:a:$g_audio_stream_idx 384k"
    elif [ "$g_enchannels" -ge 2 ]
    then
      g_audio_codec_opts="$g_audio_codec_opts -c:a:$g_audio_stream_idx libfdk_aac -profile:a:$g_audio_stream_idx aac_he_v2 -b:a:$g_audio_stream_idx 48k -ac:a:$g_audio_stream_idx 2"
    else
      g_audio_codec_opts="$g_audio_codec_opts -c:a:$g_audio_stream_idx libfdk_aac -profile:a:$g_audio_stream_idx aac_he -b:a:$g_audio_stream_idx 24k -ac:a:$g_audio_stream_idx 1"
    fi
    g_audio_stream_idx=$((g_audio_stream_idx + 1))
  fi

  # Select execution mode: local (sh -c) or remote docker via SSH
  local sshstream="ssh -p33 -o ServerAliveInterval=30 -o ServerAliveCountMax=6 -o ConnectTimeout=15 -o TCPKeepAlive=yes -o BatchMode=yes ${g_remotedockerffmpeg}"
  [ -z ${g_remotedockerffmpeg} ] && sshstream="sh -c"
  g_echo "Encoding video ($g_vid) on ${g_remotedockerffmpeg:-local}"

  # Build audio stream mapping: always map DE first, then EN if separate
  local g_map_audio="-map $g_audstream_de"
  if [ -n "$g_audstream_en" ] && [ "$g_audstream_en" != "$g_audstream_de" ]
  then
    g_map_audio="$g_map_audio -map $g_audstream_en"
  fi

  # Build audio language metadata and disposition flags (DE always gets default)
  local g_audio_metadata=""
  local g_audio_disposition=""
  local idx=0
  [ -n "$g_audlang_de" ] && g_audio_metadata="-metadata:s:a:$idx language=$g_audlang_de"
  g_audio_disposition="-disposition:a:$idx default"
  idx=$((idx + 1))
  if [ -n "$g_audstream_en" ] && [ "$g_audstream_en" != "$g_audstream_de" ] && [ -n "$g_audlang_en" ]
  then
    g_audio_metadata="$g_audio_metadata -metadata:s:a:$idx language=$g_audlang_en"
    g_audio_disposition="$g_audio_disposition -disposition:a:$idx 0"
  fi

  #local x265_params="vbv-maxrate=${g_vidmaxratenew}:vbv-bufsize=$(( g_vidmaxratenew * 3 / 2 )):aq-mode=3:aq-strength=1.5:no-sao=1:deblock=-1:-1:rd=6:subme=5:ref=6:bframes=4:b-adapt=2:merange=64:rc-lookahead=40:log-level=error:no-info=1"  
  local x265_params="vbv-maxrate=${g_vidmaxratenew}:vbv-bufsize=$(( g_vidmaxratenew * 3 / 2 )):aq-mode=3:aq-strength=1.5:no-sao=1:deblock=-1:-1:rd=6:subme=5:ref=6:bframes=4:b-adapt=2:merange=64:me=umh:rc-lookahead=40:tu-inter-depth=2:tu-intra-depth=2:cbqpoffs=-2:crqpoffs=-2:log-level=error:no-info=1"

  # Stage 1: Encode video to H.265 via docker pipe, output directly to MKV
  echo "cat \"${g_viddone}-streamable\"| ${sshstream} 'cat | docker run -i --rm linuxserver/ffmpeg:7.1-cli-ls9 -loglevel warning -stats -i pipe: -map_metadata -1 -map_chapters -1 -map_metadata:s -1 -fflags +bitexact -empty_hdlr_name 1 -map $g_vidstream $g_map_audio -filter:v \"${g_vidscale}\" -c:v libx265 -crf 25 -x265-params \"${x265_params}\" -pix_fmt yuv420p10le -max_muxing_queue_size 9999 $g_audio_codec_opts $g_audio_metadata $g_audio_disposition -threads 1 -f matroska pipe:' >\"$g_viddone-raw\"" >"$g_tmp"/cmd

  # fix duration/timestamps and subtitles
  if [ -n "$g_map_orig_subs" ]
  then
    echo "ffmpeg -nostdin -loglevel warning -stats -i \"${g_viddone}-raw\" -i \"$g_vid\" -map 0:v -map 0:a $g_map_orig_subs -map_chapters -1 -map_metadata -1 -map_metadata:s -1 -fflags +bitexact -empty_hdlr_name 1 -avoid_negative_ts make_zero $g_audio_metadata $g_audio_disposition $g_sub_metadata -c:v copy -c:a copy -c:s copy -f matroska -max_muxing_queue_size 9999 -y \"$g_viddone\" && rm -f \"${g_viddone}-raw\"" >>"$g_tmp"/cmd
  else
    echo "ffmpeg -nostdin -loglevel warning -stats -i \"${g_viddone}-raw\" -map 0:v -map 0:a -map_chapters -1 -map_metadata -1 -map_metadata:s -1 -fflags +bitexact -empty_hdlr_name 1 -avoid_negative_ts make_zero $g_audio_metadata $g_audio_disposition -c:v copy -c:a copy -f matroska -max_muxing_queue_size 9999 -y \"$g_viddone\" && rm -f \"${g_viddone}-raw\"" >>"$g_tmp"/cmd
  fi

  g_echo "Start encoding:"
  if [ -e /dev/tty ]
  then
    sh -x "$g_tmp"/cmd 2>/dev/tty
  else
    sh -x "$g_tmp"/cmd
  fi

  # Helper: output only valid if HEVC video, HE-AAC audio AND duration matches original within 2s
  function g_out_valid {
    ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$g_viddone" 2>/dev/null | grep -q "hevc" || return 1
    ffprobe "$g_viddone" 2>&1 | egrep -iq "he-aac|ac3" || return 1
    [ "$(stat -c%s "$g_viddone" 2>/dev/null || echo 0)" -ge 10485760 ] || return 1
    local g_dur_o=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$g_vid" 2>/dev/null)
    local g_dur_n=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$g_viddone" 2>/dev/null)
    [ -n "$g_dur_o" ] && [ -n "$g_dur_n" ] || return 1
    awk -v a="$g_dur_o" -v b="$g_dur_n" 'BEGIN { d=a-b; if (d<0) d=-d; exit (d > 2) ? 1 : 0 }'
  }

  # Verify encoding succeeded; retry up to 3 times (also catches partial transfers)
  local g_try=1
  while ! g_out_valid
  do
    g_echo_warn "Encoding failed or incomplete for $g_vid (attempt $g_try/3)"
    sleep $g_wait
    if [ -e /dev/tty ]
    then
      sh -x "$g_tmp"/cmd 2>/dev/tty
    else
      sh -x "$g_tmp"/cmd
    fi
    g_try=$((g_try+1))
    [ "$g_try" -gt 3 ] && break
  done

  if ! g_out_valid
  then
    g_echo_warn "Encoding ultimately failed for $g_vid after 3 attempts - keeping original"
    g_tmp_cleanup
    return 1
  fi

  g_echo "Encoding finished — $(( $(stat -c%s "$g_viddone" 2>/dev/null) / 1048576 )) MiB"

  # clean metadata
  mkvpropedit "$g_viddone" --tags all: >/dev/null || g_echo_warn "Could not clean tags"

  # Validate output: HEVC video, HE-AACv2/AC3 audio, size, duration
  if ! g_out_valid
  then
    g_echo_warn "Output validation failed for $g_vid - keeping original"
    g_tmp_cleanup
    return 1
  fi

  g_echo "Replacing original with compressed file"
  # cat + touch: replace original keeping permissions and inode, then set mtime
  local g_timestamp=$(ls --time-style='+%Y%m%d%H%M' -l "$g_vid" | cut -d" " -f6)
  g_timestamp=$((g_timestamp+1))
  cat "$g_viddone" > "$g_vid"
  touch -t $g_timestamp "$g_vid"

  # Cleanup: remove temp dir, progress marker and reset trap
  g_tmp_cleanup
}
