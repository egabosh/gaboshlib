#!/bin/bash

function g_compress_video {
 local g_vid=$1
 local g_remotedockerffmpeg=$2

 # Datei OK und noch da?
 ffmpeg -i "$g_vid" 2>&1 | perl -pe 's/\[0x[0-9]+\]//g' >"$g_tmp"/vidinfo
 if egrep -q "Invalid data found when processing input|No such file or directory" "$g_tmp"/vidinfo
 then
  g_echo_warn "Video $g_vid existiert nicht (mehr) oder ist defekt."
  return 1
 fi


 # Bereits bearbeitet?
 if egrep -q "Stream.+Video: hevc" "$g_tmp"/vidinfo
 then
  local g_lines=`cat "$g_tmp"/vidinfo | egrep -v "WARNING: | configuration: |Side data\:|audio service type\: main|Video\:.+hevc.+1280x|Video\:.+hevc.+960x|Video\:.+hevc.+[1-8][0-9][0-9]x|Audio\:.+HE-AAC\).+mono|Audio\:.+HE-AAC.+stereo|Audio\:.+ac3.+5\.1.side.|Input .+mp4.+from|vendor_id|^ +lib[a-z]+ " | wc -l`
  # Max DVD Quali
  [ -e "$g_tmp"/VID-SD ] && g_lines=`cat "$g_tmp"/vidinfo | egrep -v "WARNING: | configuration: |Side data\:|audio service type\: main|Video\:.+hevc.+720x|Video\:.+hevc.+[1-6][0-9][0-9]x|Audio\:.+HE-AAC\).+mono|Audio\:.+HE-AAC.+stereo|Audio\:.+ac3.+5\.1.side.|Input .+mp4.+from|vendor_id|^ +lib[a-z]+ " | wc -l`
  if [ $g_lines -eq '14' ]
  then
   g_echo "Video $g_vid bereits bearbeitet!"
   return 1
  fi
 fi

 local g_wait=$(($RANDOM % 60))

 until ps ax | grep -q md5sum
 do
  g_echo "md5sum already running - Waiting 2 seconds"
  sleep 2
 done
 g_echo "Please wait... Creating checksum for $g_vid."
 g_vid_md5=$(md5sum "$g_vid" | cut -d" " -f1)
 if [ -e /tmp/"$g_vid_md5".g_progressing ]
 then
  g_echo "File $g_vid seems already be compressing"
  return 1
 fi
 echo $$ > /tmp/"$g_vid_md5".g_progressing
 

 # TMPfile
 local g_rnd=`shuf -i 10000-65000 -n 1`
 local g_vidbasename=`basename "$g_vid"`
 local g_viddone="$g_tmp/$g_vidbasename-$g_rnd-DONE.mp4"
 # 5.1/6.1/7.1 Tonspuren nach vorn setzen

 cat "$g_tmp"/vidinfo | egrep "5\.1|6\.1|7\.1" >"$g_tmp"/vidinfo51
 cat "$g_tmp"/vidinfo >>"$g_tmp"/vidinfo51
 cat "$g_tmp"/vidinfo51 >"$g_tmp"/vidinfo
 
 # Videostream wählen
 g_echo "Bearbeite Video $g_vid"
 local g_vidstream=`cat "$g_tmp"/vidinfo | grep Stream | grep ": Video: " | perl -pe 's/\#/:/g; s/\(/:/g;' | cut -d: -f 2,3 | head -n1`
 g_echo "Videostream ist $g_vidstream"
 
 # Audiostream wählen
 if cat "$g_tmp"/vidinfo | grep Stream | grep ": Audio: " | egrep -q '(ger)|(deu)'
 then
  local g_audstream=`cat "$g_tmp"/vidinfo | grep Stream | grep ": Audio: " | egrep '(ger)|(deu)' | perl -pe 's/\#/:/g; s/\(/:/g;' | cut -d: -f 2,3 | head -n1`
 else
  local g_audstream=`cat "$g_tmp"/vidinfo | grep Stream | grep ": Audio: " | perl -pe 's/\#/:/g; s/\(/:/g;' | cut -d: -f 2,3 | head -n1`
 fi
 if [ -z "$g_audstream" ]
 then
  g_echo "File $g_vid seems to have no Audio-Stream"
  rm /tmp/"$g_vid_md5".g_progressing
  return 1
 fi
 g_echo "Audiostream ist $g_audstream"


 # Untertitel
 if cat "$g_tmp"/vidinfo | grep Stream | grep ": Subtitle: " | grep -i 'forced' | egrep -q '(ger)|(deu)'
 then
  local g_substream=`cat "$g_tmp"/vidinfo | grep Stream | grep ": Subtitle: " | grep -i 'forced' | egrep '(ger)|(deu)' | perl -pe 's/\#/:/g; s/\(/:/g;' | cut -d: -f 3 | head -n1`
  g_echo "Extrahiere forced Subtitle 0:$g_substream"
  cd "$g_tmp"
  mkvextract tracks "$g_vid" $g_substream:vidinfo-$g_rnd-sub
  if ls "$g_tmp/vidinfo-$g_rnd-sub"* 2>&1 | egrep -q "idx$"
  then
   export TESSDATA_PREFIX=/usr/local/vobsub2srttessdata
   LD_LIBRARY_PATH=/usr/local/vobsub2srtlibs vobsub2srt --blacklist "|" "$g_tmp/vidinfo-$g_rnd-sub"
  else
   mv "$g_tmp/vidinfo-$g_rnd-sub" "$g_tmp/vidinfo-$g_rnd-sub.srt"
  fi
  ffmpeg -loglevel error -i "$g_tmp/vidinfo-$g_rnd-sub.srt" -y "$g_viddone.ass" < /dev/null 2>/dev/null 2>&1
 else
  local g_viddir=`dirname "$g_vid"`
  local g_vidfile=`basename "$g_vid"`
  local g_subfile=`echo "$g_vidfile" | perl -pe 's/....$/-forced/'`
  if find "$g_viddir" -name "$g_subfile.idx" | grep -q "$g_subfile.idx"
  then
   g_echo "sub/idx Untertitel gefunden - Konvertiere nach srt -> ass ($g_subfile)"
   rm -f `find \"$g_viddir\" -name \"$g_subfile.srt\"`
   export TESSDATA_PREFIX=/usr/local/vobsub2srttessdata
   LD_LIBRARY_PATH=/usr/local/vobsub2srtlibs vobsub2srt --blacklist "|" "`find \"$g_viddir\" -name \"$g_subfile.idx\" | perl -pe 's/.idx$//'`"
  fi
  if find "$g_viddir" -name "$g_subfile.srt" | grep -q "$g_subfile.srt"
  then
   g_echo "srt Untertitel gefunden - Konvertiere nach ass ($g_subfile)"
   ffmpeg -loglevel error -i "`find \"$g_viddir\" -name \"$g_subfile.srt\"`" -y "$g_viddone.ass" < /dev/null 2>/dev/null 2>&1
  fi
 fi
 
 # Video Auflösung und Bitrate neu definieren
 local g_vidwidth=`cat "$g_tmp"/vidinfo | egrep "Stream.+Video" | perl -pe 's/ /\n/g;' | egrep "[0-9]x[0-9]" | cut -d"x" -f 1 | perl -pe 's/[^0-9]//g'`
 local g_vidmaxrate=$(mediainfo -f "$g_vid" | egrep "^Overall bit rate +: .+kb/s" | head -n1 | perl -pe 's/ +//g;' | cut -d: -f2 | cut -d"k" -f1)
 if [ -z $g_vidwidth ]
 then
  g_echo_warn "Konnte Auflösung von Video $g_vid nicht ermitteln."
  return 1
 fi
 if [ -z $g_vidmaxrate ]
 then
  g_echo "Konnte maxinale Bitrate von Video $g_vid nicht ermitteln. - Gehe von 3600 kb/s aus"
  g_vidmaxrate=3600
 fi
 g_echo "Bitrate des Originals $g_vidmaxrate kb/s"
 local g_vidwidthnew=$g_vidwidth
 # VCD
 [ "$g_vidwidth" -lt "420" ] && g_vidmaxratenew="900"
 # SVCD
 [ "$g_vidwidth" -ge "420" ] && g_vidmaxratenew="1200"
 # DVD
 [ "$g_vidwidth" -ge "640" ] && g_vidmaxratenew="1800"
 [ "$g_vidwidth" -ge "700" ] && g_vidwidthnew=720
 if ! [ -e "$g_tmp"/VID-SD ]
 then
  # HD720p Anamorphic
  [ "$g_vidwidth" -ge "911" ] && g_vidwidthnew=960
  [ "$g_vidwidth" -ge "911" ] && g_vidmaxratenew="2700"
  # HD720p
  [ "$g_vidwidth" -gt "1250" ] && g_vidwidthnew=1280
  [ "$g_vidwidth" -gt "1250" ] && g_vidmaxratenew="3600"
 fi
 # Bei 4:3-Videos nicht mehr als 960xX@2700k um Platz zu sparen
 if egrep -q "Video.+4:3" "$g_tmp"/vidinfo
 then
  if [ "$g_vidwidthnew" -gt "960" ]
  then
   g_vidwidthnew=960
   g_vidmaxratenew="2700"
  fi
 fi

 # Falls Originalbitrate niedriger ist Bitrate entsprechend anpassen
 [ $g_vidmaxrate -lt $g_vidmaxratenew ] && g_vidmaxratenew=$g_vidmaxrate

 # Seitenverhältnis 1:1
 local g_vidscale="scale=$g_vidwidthnew:-2"

 # Audioqualität generell für 5.1 oder andere Formate
 local g_audionew="-c:a ac3 -b:a 384k"
 #g_audionew="-c:a libfdk_aac -profile:a aac_he -b:a 144k" # <-- Leider schlechte Qualität bei den hinteren Kanälen auf Raspberry
 # bei unter 5.1 zu Stereo
 cat $g_tmp/vidinfo | grep "Stream #$g_audstream" | egrep -q 'stereo|3\.1|4\.0|5\.0' && g_audionew="-ac 2 -c:a libfdk_aac -profile:a aac_he_v2 -b:a 48k"
 # bei Mono
 cat $g_tmp/vidinfo | grep "Stream #$g_audstream" | egrep -q "mono" && g_audionew="-ac 1 -c:a libfdk_aac -profile:a aac_he -b:a 24k"
 
 local g_ass=""
 # ASS Untertitel-Dateien
 if [ -f "${g_viddone}.ass" ]
 then
 # Untertitel einbrennen
  g_ass="ass=${g_viddone}.ass,"
 fi
 
 echo "ffmpeg -loglevel warning -stats -i \"${g_vid}\" -c:v copy -c:a copy  -movflags +faststart -f mp4 \"${g_viddone}-streamable\" < /dev/null 2>&1" >"$g_tmp"/cmd
 sshstream="ssh -p33 ${g_remotedockerffmpeg}"
 [ -z ${g_remotedockerffmpeg} ] && sshstream="sh -c"
 g_echo "Baue MP4 ($g_vid) ${g_remotedockerffmpeg}"
 echo "cat \"${g_viddone}-streamable\"| $sshstream 'cat | docker run -i --rm linuxserver/ffmpeg -loglevel warning -stats -i pipe: -f mp4 -map_metadata -1 -map_chapters -1 -map $g_vidstream -map $g_audstream -filter:v \"${g_ass}${g_vidscale}\" -c:v libx265 -crf 25 -x265-params \"vbv-maxrate=${g_vidmaxratenew}:vbv-bufsize=${g_vidmaxratenew}:log-level=warning\" -pix_fmt yuv420p -max_muxing_queue_size 9999 $g_audionew -threads 1 -movflags +faststart+empty_moov+delay_moov -f mp4 pipe:' >\"${g_viddone}-stream\"" >>"$g_tmp"/cmd
 echo "ffmpeg -loglevel warning -stats -i \"${g_viddone}-stream\" -c:v copy -c:a copy  -movflags +faststart -f mp4 \"$g_viddone\" < /dev/null 2>&1" >>"$g_tmp"/cmd

 cat "$g_tmp"/cmd
 sh "$g_tmp"/cmd
 # Wiederholen falls schief gelaufen
 local g_try=2
 while ffmpeg -i "$g_viddone" 2>&1 | egrep -q "moov atom not found|No such file or directory"
 do
  g_echo_warn "Fehler in ffmpeg $g_vid"
  sleep $g_wait
  cat $g_tmp/cmd
  sh $g_tmp/cmd
  g_try=$((g_try+1))
  rm /tmp/"$g_vid_md5".g_progressing
  [ "$g_try" -gt "3" ] && return 1
 done
 local g_timestamp=$(ls --time-style='+%Y%m%d%H%M' -l "$g_vid" | cut -d" " -f6)
 # For update-copy or rsync one second newer file
 g_timestamp=$((g_timestamp+1))
 cat "$g_viddone" >"$g_vid"
 touch -t $g_timestamp "$g_vid"
 rm "$g_viddone" "${g_viddone}-streamable" "${g_viddone}-stream"
 rm /tmp/"$g_vid_md5".g_progressing
}
