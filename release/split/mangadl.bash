#!/usr/bin/env bash
_usage(){
printf "%b" "
The script can be used to search and download mangas from various sources.\n

Supported sources: ${ALL_SOURCES[*]:-No sources available.}

Default source: ${SOURCE:-Not set}

Usage: ${0##*/} manga_name/manga_url [options.. ]\n
Options:\n
  -d | --directory - Custom workspace folder.\n
  -s | --source 'name of source' - Source where the input will be searched.\n
      To change default source, use mangadl -s default=sourcename\n
  -n | --num 'no of searches' - No. of searches to show, default is 10.\n
      To change default no of searches, use mangadl -n default='no of searches'\n
  -p | --parallel 'no of jobs'  - No. of parallel jobs to use.\n
  -r | --range - Custom range, can be given with this flag as argument, or if not given, then will be asked later in the script.\n
      e.g: -r '1 5-10 11 12-last last', this will download chapter number 1, 5 to 10 and 11. For more info, see README.\n
  -c | --convert 'quality between 0 to 99' - Decrease quality of images by the given percentage using convert ( imagemagick ).\n
  -z | --zip - Create zip of downloaded images.\n
  --upload - Upload created zip on pixeldrain.com.\n
  --skip-internet-check - Like the flag says.\n
  --info - Show detailed info, only if script is installed system wide.\n
  -u | --update - Update the installed script in your system.\n
  --uninstall - Uninstall script, remove related files.\n
  -D | --debug - Display script command trace, use before all the flags to see maximum script trace.\n
  -h | --help - Display usage instructions.\n"
exit
}
_short_help(){
printf "No valid arguments provided, use -h/--help flag to see usage.\n"
exit
}
_auto_update(){
export REPO
(_REPO="$REPO"
command -v "$COMMAND_NAME" 1> /dev/null&&if [[ -n ${_REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+$TYPE_VALUE}}}} ]];then
current_time="$(printf '%(%s)T\n' "-1")"
[[ $((LAST_UPDATE_TIME+AUTO_UPDATE_INTERVAL)) -lt $current_time ]]&&_update
_update_value LAST_UPDATE_TIME "$current_time"
fi) \
2>| /dev/null 1>&2&
return 0
}
_update(){
declare job="${1:-update}"
[[ $GLOBAL_INSTALL == true ]]&&! [[ $(id -u) == 0 ]]&&printf "%s\n" "Error: Need root access to update."&&return 0
[[ $job =~ uninstall ]]&&job_string="--uninstall"
_print_center "justify" "Fetching $job script.." "-"
declare repo="${REPO:-Akianonymus/mangadl-bash}" type_value="${TYPE_VALUE:-latest}"
{ [[ ${TYPE:-} != branch ]]&&type_value="$(_get_latest_sha release "$type_value" "$repo")";}||:
if script="$(curl --compressed -Ls "https://raw.githubusercontent.com/$repo/$type_value/release/install")";then
_clear_line 1
printf "%s\n" "$script"|bash -s -- ${job_string:-} --skip-internet-check
current_time="$(printf '%(%s)T\n' "-1")"
_update_value LAST_UPDATE_TIME "$current_time"&
else
_clear_line 1
"${QUIET:-_print_center}" "justify" "Error: Cannot download $job script." "=" 1>&2
exit 1
fi
exit "$?"
}
_update_value(){
declare command_path="${INSTALL_PATH:?}/$COMMAND_NAME" \
value_name="${1:-}" value="${2:-}" script_without_value_and_shebang
script_without_value_and_shebang="$(grep -v "$value_name=\".*\".* # added values" "$command_path"|sed 1d)"
new_script="$(sed -n 1p "$command_path"
printf "%s\n" "$value_name=\"$value\" # added values"
printf "%s\n" "$script_without_value_and_shebang")"
chmod +w "$command_path"&&printf "%s\n" "$new_script" >| "$command_path"&&chmod -w "$command_path"
return 0
}
_version_info(){
if command -v "$COMMAND_NAME" 1> /dev/null&&[[ -n ${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+$TYPE_VALUE}}}} ]];then
for i in REPO INSTALL_PATH TYPE TYPE_VALUE LATEST_INSTALLED_SHA;do
printf "%s\n" "$i=\"${!i}\""
done|sed -e "s/=/: /g"
else
printf "%s\n" "mangadl-bash is not installed system wide."
fi
exit 0
}
_setup_arguments(){
unset DEBUG FOLDER SOURCE NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD MAX_BACKGROUD_JOBS NUM_OF_SEARCH \
MODIFY_RANGE GIVEN_RANGE DECREASE_QUALITY CONVERT CONVERT_DIR CREATE_ZIP UPLOAD_ZIP SKIP_INTERNET_CHECK INPUT_ARRAY
CONFIG="$HOME/.mangadl-bash.conf"
[[ -f $CONFIG ]]&&. "$CONFIG"
SOURCE="${SOURCE:-mangahub}"
_check_longoptions(){
[[ -z $2 ]]&&printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "$1" "${0##*/}"&&exit 1
return 0
}
url_regex='(http|https)://[a-zA-Z0-9./?=_%:-]*'
source_regex='(http|https)://.*('$(printf "%s|" "${ALL_SOURCES[@]}")examplemanga')[a-zA-Z0-9./?=_%:-]'
while [[ $# -gt 0 ]];do
case "$1" in
-h|--help)_usage;;
-D|--debug)DEBUG="true"&&export DEBUG;;
-u|--update)_check_debug&&_update;;
--uninstall)_check_debug&&_update uninstall;;
--info)_version_info;;
-d|--directory)_check_longoptions "$1" "$2"
FOLDER="$2"&&shift
;;
-s|--source)_check_longoptions "$1" "$2"
_SOURCE="${2/default=/}"
{ [[ $2 == default* ]]&&UPDATE_DEFAULT_SOURCE="_update_config";}||:
for _source in "${ALL_SOURCES[@]}";do
if [[ "$_source"-scraper.bash == "$_SOURCE"-scraper.bash ]];then
SOURCE="$_SOURCE"&&shift
break
fi
done
if [[ -z $SOURCE ]];then
printf "%s\n" "Error: Given source ( $2 ) is not supported."
exit 1
fi
;;
-n|--num)_check_longoptions "$1" "$2"
_NUM_OF_SEARCH="${2/default=/}"
{ [[ $2 == default* ]]&&UPDATE_DEFAULT_NUM_OF_SEARCH="_update_config";}||:
case "$_NUM_OF_SEARCH" in
all|*[0-9]*)NUM_OF_SEARCH="$2"
;;
*)printf "\nError: -n/--num accept arguments as postive integets.\n"
exit 1
esac
shift
;;
-p|--parallel)_check_longoptions "$1" "$2"
NO_OF_PARALLEL_JOBS="$2"
case "$NO_OF_PARALLEL_JOBS" in
''|*[!0-9]*)printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
exit 1
;;
*)[[ $NO_OF_PARALLEL_JOBS -gt 10 ]]&&{
NO_OF_PARALLEL_JOBS=10||NO_OF_PARALLEL_JOBS="$2"
}
esac
PARALLEL_DOWNLOAD="true"&&export PARALLEL_DOWNLOAD
shift
;;
-r|--range)MODIFY_RANGE="true"
for i in $2;do
if [[ $i =~ (^([0-9]+)-([0-9]+|last)+$|^([0-9]+|last)+$) ]];then
GIVEN_RANGE+=("$i")
fi
done
[[ -n ${GIVEN_RANGE[*]} ]]&&shift
;;
-c|--convert)_check_longoptions "$1" "$2"
DECREASE_QUALITY="$2"
case "$DECREASE_QUALITY" in
''|*[!0-9]*)printf "\nError: -c/--convert value ranges between 1 to 100.\n"
exit 1
;;
*)[[ $DECREASE_QUALITY -gt 99 ]]&&{
DECREASE_QUALITY=99||DECREASE_QUALITY="$2"
}
esac
CONVERT="true"&&CONVERT_DIR="converted"
shift
;;
-z|--zip)CREATE_ZIP="true";;
-U|--upload)UPLOAD_ZIP="true";;
--skip-internet-check)SKIP_INTERNET_CHECK=":";;
'')shorthelp;;
*)if
[[ $1 == -* ]]
then
printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "$1" "${0##*/}"&&exit 1
else
INPUT_ARRAY+=("$1")
fi
esac
shift
done
_check_debug
SOURCE="${SOURCE:-mangahub}"
"${UPDATE_DEFAULT_SOURCE:-:}" SOURCE "$SOURCE" "$CONFIG"
NUM_OF_SEARCH="${NUM_OF_SEARCH:-10}"
"${UPDATE_DEFAULT_NUM_OF_SEARCH:-:}" NUM_OF_SEARCH "$NUM_OF_SEARCH" "$CONFIG"
{ [[ $NUM_OF_SEARCH == all ]]&&unset NUM_OF_SEARCH;}||:
CORES="$({ nproc||sysctl -n hw.logicalcpu;} 2>| /dev/null)"
NO_OF_PARALLEL_JOBS="${NO_OF_PARALLEL_JOBS:-$CORES}"
[[ -z ${INPUT_ARRAY[*]} ]]&&_short_help
export -f _basename _tail _regex
return 0
}
_source_manga_util(){
SOURCE="${1:-$SOURCE}"
case "$SOURCE" in
*mangakakalot*)SOURCE="manganelo";;
*fanfox*)SOURCE="mangafox"
esac
[[ -z $SELF_SOURCE ]]&&{
utils_file="$UTILS_FOLDER/$SOURCE-scraper.bash"
if [[ -r $utils_file ]];then
. "$utils_file"||{ printf "Error: Unable to source file ( %s ) .\n" "$utils_file" 1>&2&&exit 1;}
else
printf "Error: Utils file ( %s ) not found\n" "$utils_file" 1>&2
exit 1
fi
}
return 0
}
_process_arguments(){
declare input utils_file _exit
_source_manga_util
CURRENT_DIR="$PWD"
{ [[ -n $FOLDER ]]&&mkdir -p "$FOLDER"&&{ cd "${FOLDER:-.}"||exit 1;};}||:
declare -A Aseen
for input in "${INPUT_ARRAY[@]}";do
{ [[ ${Aseen[$input]} ]]&&continue;}||Aseen[$input]=x
if [[ $input =~ $url_regex ]];then
if [[ $input =~ $source_regex ]];then
source_of_url="$(_regex "$input" ''"$(printf "%s|" "${ALL_SOURCES[@]}")examplemanga"'' 0)"
_source_manga_util "$source_of_url"
_print_center "justify" "Fetching manga details.." "-"
_fetch_manga_details_"$SOURCE" "$input" fetch_name||{ _clear_line 1&&_print_center "justify" "Error: Invalid manga url." "="&&_newline "\n"&&continue;}
_clear_line 1
_print_center "justify" "$NAME" "="
else
_print_center "justify" "URL not supported." "="
_newline "\n"&&continue
fi
else
unset _exit option RANGE _option _RANGE
_print_center "justify" "$input" "="
_print_center "justify" "Searching in" " $SOURCE" "-"
_search_manga_"$SOURCE" "$input" "$NUM_OF_SEARCH"||_exit="1"
_clear_line 1
_print_center "justify" "Source" ": $SOURCE" "="
_print_center "justify" "${TOTAL_SEARCHES:-0} results found" "="
{ [[ -n $_exit ]]&&_newline "\n"&&continue;}||:
printf "\n%s\n" "${OPTION_NAMES[@]}"&&_newline "\n"
"${QUIET:-_print_center}" "normal" " Choose " "-"
until [[ $option =~ ^([0-9]+)+$ && $option -gt 0 && $option -le ${#OPTION_NAMES[@]} ]];do
[[ -n $_option ]]&&_clear_line 1
printf -- "-> "
read -r option&&_option=1
done
_set_manga_variables_"$SOURCE" "$option"
_print_center "justify" "$NAME" "="
_print_center "justify" "Fetching manga details.." "-"
_fetch_manga_details_"$SOURCE" "$URL"
_clear_line 1
fi
export SOURCE
mkdir -p "$NAME"
FULL_PATH_NAME="$(printf "%s/%s\n" "$(cd "$(_dirname "$NAME")" &> /dev/null&&pwd)" "${NAME##*/}")"
cd "$NAME"||exit 1
FINAL_RANGE="${PAGES[0]}"-"${PAGES[$((${#PAGES[@]}-1))]}"
if [[ -n $MODIFY_RANGE ]];then
if [[ -z ${GIVEN_RANGE[*]} ]];then
_print_center "justify" "Input chapters" "-"
printf "%b " "${PAGES[@]}"&&_newline "\n\n"
"${QUIET:-_print_center}" "normal" " Give range, e.g: 1 2-10 69 " "-"
until [[ -n ${GIVEN_RANGE[*]} ]];do
[[ -n $_GIVEN_RANGE ]]&&_clear_line 1
printf -- "-> "
read -ra GIVEN_RANGE&&_GIVEN_RANGE=1
done
fi
_check_and_create_range "${GIVEN_RANGE[@]}"||continue
mapfile -t PAGES <<< "$(printf "%s\n" "${PAGES[@]}"|sed -e "s/^/_-_-_/g" -e "s/$/_-_-_/g")"
for _range in "${RANGE[@]}";do
regex=""
if [[ $_range == *-* ]];then
regex="_-_-_${_range/-*/}_-_-_.*_-_-_${_range/*-/}_-_-_"
[[ ${PAGES[*]} =~ $regex ]]&&TEMP_PAGES+="$(: "${BASH_REMATCH[@]//_-_-_ _-_-_/$'\n'}"&&printf "%s\n" "${_//_-_-_/}")
"
else
regex="_-_-_${_range}_-_-_"
[[ ${PAGES[*]} =~ $regex ]]&&TEMP_PAGES+="$(: "${BASH_REMATCH[@]//_-_-_ _-_-_/$'\n'}"&&printf "%s\n" "${_//_-_-_/}")
"
fi
done
mapfile -t PAGES <<< "$TEMP_PAGES"
mapfile -t PAGES <<< "$(_remove_array_duplicates "${PAGES[@]}")"
FINAL_RANGE="$(: "$(_remove_array_duplicates "${RANGE[@]}")"&&printf "%s\n" "${_//$'\n'/,}")"
fi
TOTAL_CHAPTERS="${#PAGES[@]}"
_print_center "justify" "$TOTAL_CHAPTERS chapter(s)" "="
_print_center "justify" "Fetching" " chapter details.." "-"
mkdir -p "${PAGES[@]}"
_fetch_manga_chapters
_clear_line 1
_print_center "justify" "Counting Images.." "-"
_count_images_"$SOURCE"
for _ in {1..2};do _clear_line 1;done
_print_center "justify" "$TOTAL_CHAPTERS chapters" " | $TOTAL_IMAGES images" "="
_print_center "justify" "Downloading" " images.." "-"&&_newline "\n"
_download_images
_clear_line 1
TOTAL_IMAGES="$(_count <<< "$IMAGES")"
_print_center "justify" "$TOTAL_IMAGES" " images downloaded." "="
_print_center "justify" "$TOTAL_IMAGES_SIZE" "="&&_newline "\n"
if [[ -n $CONVERT ]];then
if command -v convert 1> /dev/null;then
_print_center "justify" "Converting images.." "-"
_print_center "justify" "Quality to decrease: $DECREASE_QUALITY%" "="&&_newline "\n"
export DECREASE_QUALITY CONVERT_DIR
{ mkdir -p "$CONVERT_DIR"&&cd "$CONVERT_DIR"&&mkdir -p "${PAGES[@]}"&&cd - &> /dev/null;}||exit 1
export -f _dirname _basename _name
printf "%s\n" "$IMAGES"|xargs -n1 -P"${NO_OF_PARALLEL_JOBS:-$((CORES*2))}" -i bash -c '
                image="{}"
                target_image="${CONVERT_DIR}"/"$(_dirname "${image/.\//}")"/"$(_basename "$(_name "${image%.*}")")".jpg
                current_quality="$(identify  -format %Q "{}")"
                new_quality="$((DECREASE_QUALITY < current_quality ? (current_quality - DECREASE_QUALITY) : current_quality))"
                if [[ ${new_quality} -lt ${current_quality} || ${image} =~ png ]] && convert "${image}" -quality "${new_quality}" "${target_image}" &> /dev/null; then
                    printf "1\n"
                else
                    printf "2\n" 1>&2
                    cp -u "${image}" "${target_image}"
                fi
                ' 1> "$TMPFILE".success 2> "$TMPFILE".error&
pid="$!"
until [[ -f "$TMPFILE".success || -f "$TMPFILE".error ]];do sleep 0.5;done
until ! kill -0 "$pid" 2>| /dev/null 1>&2;do
SUCCESS_STATUS="$(_count < "$TMPFILE".success)"
ERROR_STATUS="$(_count < "$TMPFILE".error)"
sleep 1
if [[ $TOTAL_STATUS != "$((SUCCESS_STATUS+ERROR_STATUS))" ]];then
_clear_line 1
_print_center "justify" "$SUCCESS_STATUS converted" " | $ERROR_STATUS copied" "="
else
break
fi
TOTAL_STATUS="$((SUCCESS_STATUS+ERROR_STATUS))"
done
rm -f "$TMPFILE".success "$TMPFILE".error
for _ in {1..3};do _clear_line 1;done
_print_center "justify" "Converted $TOTAL_IMAGES" " images ( $DECREASE_QUALITY% )" "="
else
_print_center "justify" "Imagemagick not installed, skipping conversion.." "="
unset CONVERT_DIR
fi
fi
if [[ -n $CREATE_ZIP ]];then
if command -v zip 1> /dev/null;then
_print_center "justify" "Creating zip.." "="&&_newline "\n"
cd "${CONVERT_DIR:-.}"||exit
ZIPNAME="$NAME${FINAL_RANGE+_$FINAL_RANGE}${CONVERT_DIR+_decreased_$DECREASE_QUALITY%}".zip
zip -x "*chapter" "*images" -u -q -r9 -lf "$TMPFILE".log -li -la "$FULL_PATH_NAME"/"$ZIPNAME" "${PAGES[@]}"&
pid="$!"
until [[ -f "$TMPFILE".log ]];do sleep 0.5;done
TOTAL_ZIP_STATUS="$((TOTAL_IMAGES+TOTAL_CHAPTERS))"
until ! kill -0 "$pid" 2>| /dev/null 1>&2;do
STATUS=$(grep 'up to date\|updating\|adding' "$TMPFILE".log -c)
sleep 0.5
if [[ $STATUS != "$OLD_STATUS" ]];then
_clear_line 1
_print_center "justify" "$STATUS" " / $TOTAL_ZIP_STATUS" "="
fi
OLD_STATUS="$STATUS"
done
for _ in {1..2};do _clear_line 1;done
rm -f "$TMPFILE".log
ZIP_SIZE="$(_bytes_to_human "$(wc -c < "$FULL_PATH_NAME/$ZIPNAME")")"
_print_center "justify" "$ZIPNAME" "="
_newline "\n"&&_print_center "normal" "Path: \"${FULL_PATH_NAME/$CURRENT_DIR\//}/$ZIPNAME\" " " "&&_newline "\n"
_print_center "justify" "$ZIP_SIZE" "="&&_newline "\n"
if [[ -n $UPLOAD_ZIP ]];then
_print_center "justify" "Uploading zip.." "-"
DOWNLOAD_URL="$(upload "$ZIPNAME")"
for _ in {1..2};do _clear_line 1;done
_print_center "justify" "ZipLink" "="
_print_center "normal" "$(printf "%b\n" "\xe2\x86\x93 \xe2\x86\x93 \xe2\x86\x93")" " "
_print_center "normal" "$DOWNLOAD_URL" " "&&_newline "\n"
fi
else
_print_center "justify" "zip not installed, skipping zip creation.." "="
fi
fi
done
return 0
}
main(){
[[ $# == 0 ]]&&_short_help
[[ -z $SELF_SOURCE ]]&&{
UTILS_FOLDER="${UTILS_FOLDER:-${INSTALL_PATH:-./utils}}"
{ . "$UTILS_FOLDER"/common-utils.bash&&. "$UTILS_FOLDER"/scraper-utils.bash;}||{ printf "Error: Unable to source util files.\n"&&exit 1;}
for _source in "$UTILS_FOLDER"/*scraper.bash;do
ALL_SOURCES+=("$(_basename "${_source/-scraper.bash/}")")
done
}
_check_bash_version&&set -o errexit -o noclobber -o pipefail
_setup_arguments "$@"
"${SKIP_INTERNET_CHECK:-_check_internet}"
[[ -n $PARALLEL_DOWNLOAD ]]&&{
{ command -v mktemp 1>| /dev/null&&TMPFILE="$(mktemp -u)";}||TMPFILE="$PWD/$(printf '%(%s)T\n' "-1").LOG"
}
_cleanup(){
{
[[ -n $PARALLEL_DOWNLOAD ]]&&rm -f "${TMPFILE:?}"*
export abnormal_exit&&if [[ -n $abnormal_exit ]];then
printf "\n\n%s\n" "Script exited manually."
kill -- -$$
else
_auto_update
fi
} 2>| /dev/null||:
return 0
}
trap 'abnormal_exit="1"; exit' INT TERM
trap '_cleanup' EXIT
START="$(printf '%(%s)T\n' "-1")"
_process_arguments
END="$(printf '%(%s)T\n' "-1")"
DIFF="$((END-START))"
"${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF/60))"" minute(s) and ""$((DIFF%60))"" seconds " "="
}
{ [[ -z ${SOURCED_MANGADL:-} ]]&&main "$@";}||:
