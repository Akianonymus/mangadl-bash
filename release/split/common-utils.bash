#!/usr/bin/env bash
_basename(){
declare tmp
tmp=${1%"${1##*[!/]}"}
tmp=${tmp##*/}
tmp=${tmp%"${2/"$tmp"/}"}
printf '%s\n' "${tmp:-/}"
}
_bytes_to_human(){
declare b=${1:-0} d='' s=0 S=(Bytes {K,M,G,T,P,E,Y,Z}B)
while ((b>1024));do
d="$(printf ".%02d" $((b%1024*100/1024)))"
b=$((b/1024))&&((s++))
done
printf "%s\n" "$b$d ${S[$s]}"
}
_check_bash_version(){
{ ! [[ ${BASH_VERSINFO:-0} -ge 4 ]]&&printf "Bash version lower than 4.x not supported.\n"&&exit 1;}||:
}
_check_debug(){
_print_center_quiet(){ { [[ $# == 3 ]]&&printf "%s\n" "$2";}||{ printf "%s%s\n" "$2" "$3";};}
if [[ -n $DEBUG ]];then
set -x&&PS4='-> '
_print_center(){ { [[ $# == 3 ]]&&printf "%s\n" "$2";}||{ printf "%s%s\n" "$2" "$3";};}
_clear_line(){ :;}&&_newline(){ :;}
else
if [[ -z $QUIET ]];then
if _support_ansi_escapes;then
shopt -s checkwinsize&&(:&&:)
if [[ $COLUMNS -lt 45 ]];then
_print_center(){ { [[ $# == 3 ]]&&printf "%s\n" "[ $2 ]";}||{ printf "%s\n" "[ $2$3 ]";};}
else
trap 'shopt -s checkwinsize; (:;:)' SIGWINCH
fi
CURL_PROGRESS="-#" EXTRA_LOG="_print_center" CURL_PROGRESS_EXTRA="-#"
export CURL_PROGRESS EXTRA_LOG CURL_PROGRESS_EXTRA
else
_print_center(){ { [[ $# == 3 ]]&&printf "%s\n" "[ $2 ]";}||{ printf "%s\n" "[ $2$3 ]";};}
_clear_line(){ :;}
fi
_newline(){ printf "%b" "$1";}
else
_print_center(){ :;}&&_clear_line(){ :;}&&_newline(){ :;}
fi
set +x
fi
}
_check_internet(){
"${EXTRA_LOG:-:}" "justify" "Checking Internet Connection.." "-"
if ! _timeout 10 curl -Is google.com;then
_clear_line 1
"${QUIET:-_print_center}" "justify" "Error: Internet connection" " not available." "="
exit 1
fi
_clear_line 1
}
_check_and_create_range(){
declare mode="${1:?}" tmp&&shift
case "$mode" in
relative)for range in "$@"
do
unset start end _start _end
if [[ $range =~ ^([0-9.]+)-([0-9.]+|last)+$ ]];then
_start="${range/-*/}" _end="${range/*-/}"
[[ $_end == last ]]&&_end="${#PAGES[@]}"
if [[ $_start -gt $_end ]];then
_start="$_end"
_end="${range/-*/}"
elif [[ $_start -eq $_end ]];then
[[ $_start -lt 1 ]]&&_start=1
[[ $_start -gt ${#PAGES[@]} ]]&&_start="${#PAGES[@]}"
start="${PAGES[$((_start-1))]}"
[[ -z $start ]]&&printf "%s\n" "Error: invalid chapter ( $start )."&&return 1
RANGE+=("$start")
continue
fi
[[ $_start -lt 1 ]]&&_start=1
[[ $_end -gt ${#PAGES[@]} ]]&&_end="${#PAGES[@]}"
[[ $_start == "$_end" ]]&&unset _end
start="${PAGES[$((_start-1))]}"
[[ -z $start ]]&&printf "%s\n" "Error: invalid chapter ( $start )."&&return 1
[[ -n $_end ]]&&end="${PAGES[$((_end-1))]}"
RANGE+=("$start${end:+-$end}")
elif [[ $range =~ ^([0-9.]+|last)+$ ]];then
{ [[ $range == last ]]&&_start="${#PAGES[@]}";}||{
[[ $range -lt 1 ]]&&_start=1
[[ $range -gt ${#PAGES[@]} ]]&&_start="${#PAGES[@]}"
}
_start="${_start:-$range}"
start="${PAGES[$((_start-1))]}"
[[ -z $start ]]&&printf "%s\n" "Error: invalid chapter ( $start )."&&return 1
RANGE+=("$start")
else
printf "%s\n" "Error: Invalid range ( $range )."&&return 1
fi
done
;;
absolute)_tmp=" ${PAGES[*]} "
for range in "$@";do
unset _start _end
if [[ $range =~ ^([0-9.]+)-([0-9.]+|last)+$ ]];then
_start="${range//-*/}" _end="${range//*-/}"
[[ $_end == last ]]&&: "${#PAGES[@]}"&&_end="${PAGES[$((_-1))]}"
[[ -n ${_tmp//* $_start */} ]]&&printf "%s\n" "Error: invalid chapter ( $_start )."&&return 1
[[ -n ${_tmp//* $_end */} ]]&&printf "%s\n" "Error: invalid chapter ( $_end )."&&return 1
if [[ $_start > $_end ]];then
_start="$_end"
_end="${range/-*/}"
elif [[ $_start == "$_end" ]];then
RANGE+=("$_start")
continue
fi
RANGE+=("$_start${_end:+-$_end}")
elif [[ $range =~ ^([0-9.]+|last)+$ ]];then
{ [[ $range == last ]]&&_start="${#PAGES[@]}";}||_start="$range"
[[ -n ${_tmp//* $_start */} ]]&&printf "%s\n" "Error: invalid chapter ( $_start )."&&return 1
RANGE+=("$start")
else
printf "%s\n" "Error: Invalid range ( $range )."&&return 1
fi
done
esac
return 0
}
_clear_line(){
printf "\033[%sA\033[2K" "$1"
}
_count(){
mapfile -tn 0 lines
printf '%s\n' "${#lines[@]}"
}
_dirname(){
declare tmp=${1:-.}
[[ $tmp != *[!/]* ]]&&{ printf '/\n'&&return;}
tmp="${tmp%%"${tmp##*[!/]}"}"
[[ $tmp != */* ]]&&{ printf '.\n'&&return;}
tmp=${tmp%/*}&&tmp="${tmp%%"${tmp##*[!/]}"}"
printf '%s\n' "${tmp:-/}"
}
_display_time(){
declare T="$1"
declare DAY="$((T/60/60/24))" HR="$((T/60/60%24))" MIN="$((T/60%60))" SEC="$((T%60))"
[[ $DAY -gt 0 ]]&&printf '%d days ' "$DAY"
[[ $HR -gt 0 ]]&&printf '%d hrs ' "$HR"
[[ $MIN -gt 0 ]]&&printf '%d minute(s) ' "$MIN"
[[ $DAY -gt 0 || $HR -gt 0 || $MIN -gt 0 ]]&&printf 'and '
printf '%d seconds\n' "$SEC"
}
_get_latest_sha(){
declare LATEST_SHA
case "${1:-$TYPE}" in
branch)LATEST_SHA="$(: "$(curl --compressed -s https://github.com/"${3:-$REPO}"/commits/"${2:-$TYPE_VALUE}".atom -r 0-2000)"
: "$(printf "%s\n" "$_"|grep -o 'Commit\/.*<' -m1||:)"&&: "${_##*\/}"&&printf "%s\n" "${_%%<*}")"
;;
release)LATEST_SHA="$(: "$(curl -L --compressed -s https://github.com/"${3:-$REPO}"/releases/"${2:-$TYPE_VALUE}")"
: "$(printf "%s\n" "$_"|grep '="/'"${3:-$REPO}""/commit" -m1||:)"&&: "${_##*commit\/}"&&printf "%s\n" "${_%%\"*}")"
esac
printf "%b" "${LATEST_SHA:+$LATEST_SHA\n}"
}
_head(){
mapfile -tn "$1" line
printf '%s\n' "${line[@]}"
}
_json_value(){
declare num _tmp no_of_lines
{ [[ $2 -gt 0 ]]&&no_of_lines="$2";}||:
{ [[ $3 -gt 0 ]]&&num="$3";}||{ [[ $3 != all ]]&&num=1;}
_tmp="$(grep -o "\"$1\"\:.*" ${no_of_lines:+-m} $no_of_lines)"||return 1
printf "%s\n" "$_tmp"|sed -e 's/.*"'"$1""\"://" -e 's/[",]*$//' -e 's/["]*$//' -e 's/[,]*$//' -e "s/^ //" -e 's/^"//' -n -e "$num"p||:
}
_name(){
printf "%s\n" "${1%.*}"
}
_print_center(){
[[ $# -lt 3 ]]&&printf "%s: Missing arguments\n" "${FUNCNAME[0]}"&&return 1
declare -i TERM_COLS="$COLUMNS"
declare type="$1" filler
case "$type" in
normal)declare out="$2"&&symbol="$3";;
justify)if
[[ $# == 3 ]]
then
declare input1="$2" symbol="$3" TO_PRINT out
TO_PRINT="$((TERM_COLS-5))"
{ [[ ${#input1} -gt $TO_PRINT ]]&&out="[ ${input1:0:TO_PRINT}..]";}||{ out="[ $input1 ]";}
else
declare input1="$2" input2="$3" symbol="$4" TO_PRINT temp out
TO_PRINT="$((TERM_COLS*47/100))"
{ [[ ${#input1} -gt $TO_PRINT ]]&&temp+=" ${input1:0:TO_PRINT}..";}||{ temp+=" $input1";}
TO_PRINT="$((TERM_COLS*46/100))"
{ [[ ${#input2} -gt $TO_PRINT ]]&&temp+="${input2:0:TO_PRINT}.. ";}||{ temp+="$input2 ";}
out="[$temp]"
fi
;;
*)return 1
esac
declare -i str_len=${#out}
[[ $str_len -ge $((TERM_COLS-1)) ]]&&{
printf "%s\n" "$out"&&return 0
}
declare -i filler_len="$(((TERM_COLS-str_len)/2))"
[[ $# -ge 2 ]]&&ch="${symbol:0:1}"||ch=" "
for ((i=0; i<filler_len; i++));do
filler="$filler$ch"
done
printf "%s%s%s" "$filler" "$out" "$filler"
[[ $(((TERM_COLS-str_len)%2)) -ne 0 ]]&&printf "%s" "$ch"
printf "\n"
return 0
}
_support_ansi_escapes(){
{ [[ -t 2 && -n $TERM && $TERM =~ (xterm|rxvt|urxvt|linux|vt) ]]&&return 0;}||return 1
}
_regex(){
[[ $1 =~ $2 ]]&&printf '%s\n' "${BASH_REMATCH[${3:-0}]}"
}
_remove_array_duplicates(){
[[ $# == 0 ]]&&printf "%s: Missing arguments\n" "${FUNCNAME[0]}"&&return 1
declare -A Aseen
Aunique=()
for i in "$@";do
{ [[ -z $i || ${Aseen[$i]} ]];}&&continue
Aunique+=("$i")&&Aseen[$i]=x
done
printf '%s\n' "${Aunique[@]}"
}
_reverse(){
for ((i="${#*}"; i>0; i--));do
printf "%s\n" "${!i}"
done
}
_tail(){
mapfile -tn 0 line
printf '%s\n' "${line[@]: -$1}"
}
_timeout(){
declare timeout="${1:?Error: Specify Timeout}"&&shift
{
"$@"&
child="$!"
trap -- "" TERM
{
sleep "$timeout"
kill -9 "$child"
}&
wait "$child"
} 2>| /dev/null 1>&2
}
_update_config(){
[[ $# -lt 3 ]]&&printf "Missing arguments\n"&&return 1
declare value_name="$1" value="$2" config_path="$3"
! [ -f "$config_path" ]&&: >| "$config_path"
chmod u+w "$config_path"
printf "%s\n%s\n" "$(grep -v -e "^$" -e "^$value_name=" "$config_path"||:)" \
"$value_name=\"$value\"" >| "$config_path"
chmod u-w+r "$config_path"
}
_upload(){
[[ $# == 0 ]]&&printf "%s: Missing arguments\n" "${FUNCNAME[0]}"&&return 1
declare input="$1" json id link
if ! [[ -f $input ]];then
printf "Given file ( %s ) doesn't exist\n" "$input"
return 1
fi
json="$(curl "-#" -F 'file=@'"$input" "https://pixeldrain.com/api/file")"||return 1
id="$(: "${json/*id*:\"/}"&&printf "%s\n" "${_/\"\}/}")"
link="https://pixeldrain.com/api/file/$id?download"
printf "%s\n" "$link"
}
_url_encode(){
declare LC_ALL=C
for ((i=0; i<${#1}; i++));do
: "${1:i:1}"
case "$_" in
[a-zA-Z0-9.~_-$2])printf '%s' "$_"
;;
*)printf '%%%02X' "'$_"
esac
done
printf '\n'
}
