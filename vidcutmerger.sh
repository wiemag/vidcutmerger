#!/usr/bin/bash
# by Wiesław Magusiak 2013-10-17
# See man pages.
VERSION=0.14
function usage () {
	echo -e "\n\e[1mvidcutmerger -i VideoFile [-o OutputClipName] [-t TimePoints] [-m] [-f fmt] [-h]\e[0m"
	echo -e "Read \e[33mman pages\e[0m to see all options and learn details."
}
function secondize () {
	PARAM=:$1
	s=0
	for ((i=1; ${#PARAM} > 0 ; i=$((i * 60)) )); do
		m=${PARAM##*:} 
		[[ ${#m} -eq 2 ]] && m=${m#0}
		s=$(( $s + $m * $i))
		PARAM=${PARAM%:*}
	done
	echo $s
}
function clockize () {
	PARAM=$1
	s=$(printf %02d $((PARAM / 3600))):
	PARAM=$((PARAM % 3600))
	echo ${s}$(printf %02d $((PARAM / 60))):$(printf %02d $((PARAM % 60)))
}
while getopts  ":i:o:t:mf:a:v:hVd" flag
do
	case "$flag" in
		i) INP="$OPTARG";; 				# Input video file
		o) OUT="$OPTARG";; 				# Base output name
		t) CUTPOINTS="$OPTARG";; 		# Text file with starting points and clips lenghts
		m) MERGE=1;; 					# Merge clips
		f) MERGE=1; FMT="$OPTARG";; 	# Format (extension); defaults to "avi" if not declared.
		a) MERGE=1; AENC="$OPTARG";; 	# copy for cutting; libmp3lame for encoding
		v) MERGE=1; VENC="$OPTARG";; 	# copy for cutting; xvid for encoding
		V) echo "Version ${VERSION}"; exit;;
		h) usage; exit;;
		d) DEBUG=1;; 					# Debug/Verbose: prints the values of some variables
	esac
done

DEBUG=${DEBUG-0}
exec 3>&1
exec 4>&2
((DEBUG)) || { exec 1>/dev/null; exec 2>/dev/null;} 

#---START--------------------------------------------------------------------------------------
[[ "x$INP" = "x" ]] && { echo "Missing input file." 1>&3 2>&4; exit 1;}
[[ -f "$INP" ]] || { echo "File $INP does not exist." 1>&3 2>&4; exit 2;}
CUTPOINTS="${CUTPOINTS-${INP%.*}.cut}"
[[ -f "${CUTPOINTS}" ]] || { echo "File ${CUTPOINTS} does not exist." 1>&3 2>&4; exit 3;}
OUT=${OUT-out} 			# base output name
OUTpath=${OUT%/*} 		# output path if included in OUT
[[ "$OUT" == "$OUTpath" ]] && OUTpath=$(pwd)
EXT=${INP##*.} 			# original video file format
MERGE=${MERGE-0}
FMT=${FMT-$EXT} 		# final output file format
x=${OUT##*.}
if [[ ${#x} == 3 && "$x" != "$OUT" ]]; then 	# assume file extension (format of video output)
	FMT=$x 				# takes precedence over the FMT declared with the -f option
	OUT=${OUT%.*} 		# make $OUT a base output name
	MERGE="1" 			# assume user wants clips merged into this format
fi
if [[ $MERGE -eq 0 || $FMT = $EXT ]]; then
	AENC=${AENC-copy}
	VENC=${VENC-copy}
else
	AENC=${AENC-libmp3lame}
	VENC=${VENC-libxvid}
fi
FPS=$(ffprobe "$INP" 2>&1 | grep tbr|cut -d, -f5|cut -d" " -f2)
MAXLEN=$(secondize $(ffprobe "$INP" 2>&1 |grep Duration|cut -d. -f1|cut -d" " -f4))
PART=1 				# clip/part number
CR=$'\n' 			# carriage return
#---Debug/Verbose mode info--------------------------------------------------------------------
echo -e "Input file: \e[1m${INP}\e[0m"
echo -e "Input file is clipped according to: \e[1m${CUTPOINTS}\e[0m"
echo Output clip files name template: "${OUT}-<num>.${EXT}"
if (($MERGE)); then
	echo -e "Output video file name: \e[1m${OUTpath}/${OUT}.${FMT}\e[0m"
	echo Audio encoder=$AENC
	echo Video encoder=$VENC
else
	echo -e "Output clips \e[1mwill NOT\e[0m be merged."
fi
echo Cutting...
[[ $(ls ${OUT}-*.${EXT} 2>/dev/null | wc -m) -gt 0 ]] && rm ${OUT}-*.${EXT}

#---A nice clipping solution that does not work------------------------------------------------
#while read -r line; do 
##while read  BEG FIN ; do 
#	echo $line
#	BEG=${line% *}
#	BEGSEK=$(secondize ${BEG})
#	FIN=${line#* }
#	FINSEK=$(secondize ${FIN})
#	LEN=$((FINSEK - BEGSEK))
#	echo "Part ${PART}: Start at ${BEG} (${BEGSEK}) and go for ${LEN} till ${FIN} sek."
#	echo Start point $(clockize $BEGSEK) Endpoint $(clockize $FINSEK);
#	ffmpeg -y -ss "$(clockize ${BEGSEK})" -t "$(clockize ${LEN})" -i "$INP" \
	#	-c:v copy -c:a copy "$OUT-$(printf %03d $PART).$EXT" 2>/dev/null 1>/dev/null
#	((PART++))
#done < "${CUTPOINTS}"

#---A little less nice (to my taste) clipping solution that does work--------------------------
FINSEK="-1"
CZAS1="0"
CZAS2="0"
declare -a lines
readarray lines < "${CUTPOINTS}"
for line in "${lines[@]}"; do
	line=${line%$CR}
	BEG=${line% *}
	if [[ $BEG == ${line/ /} ]]; then
		echo "Error:  Wrong cutting points. Check line #${PART}." 1>&3 2>&4
		exit 4
	fi
	BEGSEK=$(secondize ${BEG})
	if [[ $FINSEK -ge $BEGSEK ]]; then
		echo -e "Warning! Clips part #$((--PART)) and #$((++PART)) overlap." 1>&3 2>&4
	fi
	if [[ $BEGSEK -le $MAXLEN ]]; then
		FIN=${line#* }
		#FIN=${FIN/$CR/}
		FINSEK=$(secondize ${FIN})
		LEN=$((FINSEK - BEGSEK))
		if [[ $LEN -lt 0 ]]; then
			echo "Error:  Wrong cutting points. Check line #${PART}." 1>&3 2>&4
			exit 5
		fi
		printf "\tClip %02d:  " ${PART}
		[[ $LEN -eq 0 ]] && echo "Zero-length clip. Skipping." 1>&3 2>&4
		if [[ $LEN -gt 0 ]]; then
			echo $(clockize $BEGSEK) - $(clockize ${FINSEK}) \(${LEN}s\)
			ffmpeg -ss "$(clockize ${BEGSEK})" -y -i "$INP" -t "$(clockize ${LEN})" \
				-c:v copy -c:a copy "$OUT-$(printf %03d $PART).$EXT" 2>/dev/null 1>/dev/null
			x=$(ffprobe "$OUT-$(printf %03d $PART).$EXT" 2>&1|grep Dur|cut -d, -f1|cut -d\  -f4)
			CZAS1=$((CZAS1 + $(secondize ${x%.*})))
			x=${x#*.} 			# To avoid 08 and 09 interpreted as octal numbers
			CZAS2=$((CZAS2 + ${x#0}))
		fi
	else
		echo "Error: Clip #${PART} starting point beyond the input file length." 1>&3
		exit 6
	fi
	((PART++))
done
CZAS=$((CZAS1 + CZAS2 / 100))
CZAS2=$((CZAS2 % 100))
#---Merging. The ffmpeg version 1.1+ required (v2.0 available when this script is creted).-----
STATS="/tmp/vidcutmerger.stats"
if [[ $MERGE -eq 1 ]]; then
	echo Merging...
	OUTFRM=$(echo "$FPS * $CZAS + $FPS * $CZAS2 / 100"|bc|cut -d. -f1)
	echo -e "\tTotal number of frames:  "${OUTFRM}
	printf "\tEstimated length:        %d.%02ds" $CZAS $CZAS2
	echo "   [ $(clockize $CZAS).${CZAS2} ]"
	# Calculate original file bit rates
	VBR=$(ffprobe $INP 2>&1 |grep bitrate|cut -d" " -f8)"K"
	[[ $EXT == "mp4" && $FMT == "avi" ]] && VBR=$((${VBR%K} * 11 / 10))K
	ABR=$(($(ffprobe $INP 2>&1|grep Audio: |cut -d" " -f16)/16*16))"K"
	echo -e "\tAudio output bit rate:   "$ABR
	echo -e "\tVideo output bit rate:   "$VBR
	#ABR=$((`ffprobe $INP 2>&1|grep Audio: |cut -d" " -f16`/16*16))K 	# works too
	if [[ $FMT == $EXT ]]; then
		# Note:  -vstats_file is not created when codecs used are "copy" as hereunder.
		# Are you sure? Tested with short files, yes, I am sure.
		ffmpeg \
			-y -f concat -i <(printf "file '%s'\n" ${OUTpath}/${OUT}-*.${EXT}) \
			-c copy ${OUTpath}/${OUT}.${FMT} 2>/dev/null 
	else
		ffmpeg -vstats_file $STATS \
			-y -f concat -i <(printf "file '%s'\n" ${OUTpath}/${OUT}-*.${EXT}) \
			-c:v $VENC -b:v $VBR -c:a $AENC -ab $ABR \
			${OUTpath}/${OUT}.${FMT} 2>/dev/null &
		PID=$!
		START=$(date +%s); FR_CNT=0; ETA=0; ELAPSED=0
		while [ -e /proc/$PID ]; do # Is FFmpeg running?
			sleep 2
			CURFRM=$(awk '{gsub(/frame=/, "")}/./{line=$1-1} END{print line}' $STATS) 
			#CURFRM=$(tail -1 $STATS 2>&1 |awk '{print $2}')
			if [ $CURFRM -gt $FR_CNT ]; then # Parsed sane or no?
				FR_CNT=$CURFRM
				PROGRESS=$(( 100 * FR_CNT / OUTFRM )) # Progbar calc.
				ELAPSED=$(( $(date +%s) - START )); echo $ELAPSED > /tmp/elapsed.value
				ETA=$(date -d @$(awk 'BEGIN{print int(('$ELAPSED' / '$FR_CNT') *\
					('$OUTFRM' - '$FR_CNT'))}') -u +%H:%M:%S) # ETA calc.
			fi
			echo -ne "\rFrame: $FR_CNT of $OUTFRM Time: $(date -d @$ELAPSED -u +%H:%M:%S) ETA: $ETA ${PROGRESS}%" 1>&3 2>&4
		done
		echo -ne "\rFrame: $OUTFRM of $OUTFRM Time: $(date -d @$ELAPSED -u +%H:%M:%S) ETA: $ETA 100%" 1>&3 2>&4
		rm $STATS
	fi
	rm ${OUT}-*.${EXT}
fi
