#!/usr/bin/env bash
_download_chapter(){
declare page="$1" parallel="$2"
if [[ -f "$page/$page"_chapter && $(_tail 1 < "$page/$page"_chapter) =~ 200 ]];then
[[ -n $parallel ]]&&printf "1\n"||return 0
else
if _download_chapter_"$SOURCE" >| "$page/$page"_chapter;then
[[ -n $parallel ]]&&printf "1\n"||return 0
else
[[ -n $parallel ]]&&printf "2\n" 1>&2||return 1
fi
fi
}
_fetch_manga_chapters(){
declare SUCCESS_STATUS=0 ERROR_STATUS=0 pid
if [[ -n $PARALLEL_DOWNLOAD ]];then
{ [[ $NO_OF_PARALLEL_JOBS -gt ${#PAGES[@]} ]]&&NO_OF_PARALLEL_JOBS="${#PAGES[@]}";}||:
export -f _download_chapter _download_chapter_"$SOURCE"
printf "%s\n" "${PAGES[@]}"|xargs -n1 -P"$NO_OF_PARALLEL_JOBS" -i bash -c \
'_download_chapter "{}" true' 1> "$TMPFILE".success 2> "$TMPFILE".error&
pid="$!"
until [[ -f "$TMPFILE".success || -f "$TMPFILE".error ]];do sleep 0.5;done
_newline "\n"
until ! kill -0 "$pid" 2>| /dev/null 1>&2;do
SUCCESS_STATUS="$(_count < "$TMPFILE".success)"
ERROR_STATUS="$(_count < "$TMPFILE".error)"
sleep 1
if [[ $TOTAL_STATUS != "$((SUCCESS_STATUS+ERROR_STATUS))" ]];then
_clear_line 1
_print_center "justify" "$SUCCESS_STATUS success" " | $ERROR_STATUS failed" "="
fi
TOTAL_STATUS="$((SUCCESS_STATUS+ERROR_STATUS))"
done
rm -f "$TMPFILE".success "$TMPFILE".error
else
_newline "\n"
for page in "${PAGES[@]}";do
if _download_chapter "$page";then
SUCCESS_STATUS="$((SUCCESS_STATUS+1))"
else
ERROR_STATUS="$((ERROR_STATUS+1))"
fi
_clear_line 1 1>&2
_print_center "justify" "$SUCCESS_STATUS success" " | $ERROR_STATUS failed" "=" 1>&2
done
fi
_clear_line 1
return 0
}
_download_images(){
declare SUCCESS_STATUS=0 ERROR_STATUS=0 pid
if [[ -n $PARALLEL_DOWNLOAD ]];then
{ [[ $NO_OF_PARALLEL_JOBS -gt ${#PAGES[@]} ]]&&NO_OF_PARALLEL_JOBS="${#PAGES[@]}";}||:
printf "%s\n" "${PAGES[@]}"|xargs -n1 -P"$NO_OF_PARALLEL_JOBS" -i \
wget -P "{}" --referer="$REFERER" -c -i "{}/{}"_images &> "$TMPFILE".log&
pid="$!"
until [[ -f "$TMPFILE".log ]];do sleep 0.5;done
until ! kill -0 "$pid" 2>| /dev/null 1>&2;do
SUCCESS_STATUS="$(grep -ic 'retrieved\|saved' "$TMPFILE".log)"
ERROR_STATUS="$(grep -ic 'ERROR 404' "$TMPFILE".log)"
sleep 2
if [[ $TOTAL_STATUS != "$((SUCCESS_STATUS+ERROR_STATUS))" ]];then
_clear_line 1
_print_center "justify" "$SUCCESS_STATUS success" " | $ERROR_STATUS failed" "="
fi
TOTAL_STATUS="$((SUCCESS_STATUS+ERROR_STATUS))"
done
rm -f "$TMPFILE".log
else
for page in "${PAGES[@]}";do
log="$(wget --referer="$REFERER" -P "$page" -c -i "$page/$page"_images 2>&1)"
SUCCESS_STATUS="$(($(grep -ic 'retrieved\|saved' <<< "$log")+SUCCESS_STATUS))"
ERROR_STATUS="$(($(grep -ic 'ERROR 404' <<< "$log")+ERROR_STATUS))"
_clear_line 1 1>&2
_print_center "justify" "$SUCCESS_STATUS success" " | $ERROR_STATUS failed" "=" 1>&2
done
fi
_clear_line 1
shopt -s extglob
mapfile -t IMAGES <<< "$(_tmp="$(printf "%s/*+(jpg|png)\n" "${PAGES[@]}")"&&printf "%b\n" $_tmp)"
TOTAL_IMAGES_SIZE="$(: "$(wc -c "${IMAGES[@]}"|_tail 1|grep -Eo '[0-9]'+)"
printf "%s\n" "$(_bytes_to_human "$_")")"
export TOTAL_IMAGES_SIZE IMAGES
shopt -u extglob
return 0
}
