#!/usr/bin/env bash
_search_manga_mangafox(){
declare input="${1// /+}" num_of_search="$2"
SEARCH_HTML="$(curl -# --compressed http://m.fanfox.net/search?k="$(_url_encode "$input" +)")"
_clear_line 1
[[ $SEARCH_HTML == *"No Manga Series."* ]]&&return 1
SEARCH_HTML="$(grep --no-group-separator "post-one clearfix" -A 8 ${num_of_search:+-m $num_of_search} <<< "$SEARCH_HTML")"
mapfile -t names <<< "$(grep '"title"' <<< "$SEARCH_HTML"|grep -o '>.*<'|sed "s/\(^>\|<$\)//g")"
mapfile -t urls <<< "$(grep 'href="' <<< "$SEARCH_HTML"|grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*")"
mapfile -t status <<< "$(: "$(grep -Eo "Status:.*(Completed|Ongoing)" <<< "$SEARCH_HTML")"&&: "${_//Status: /}"&&printf "%s\n" "${_//Status:/}")"
mapfile -t genre <<< "$(: "$(grep --no-group-separator 'Status:' -B 1 <<< "$SEARCH_HTML"|grep -v 'Status:')"&&: "${_//<p>/}"&&printf "%s\n" "${_//<\/p>/}")"
i=1
while read -r -u 4 name&&read -r -u 5 _status&&read -r -u 6 _genre&&read -r -u 7 url;do
num="$((i++))"
OPTION_NAMES+=("$num. $name
   URL: $url
   Status: $_status
   Genre: $_genre")
done 4<<< "$(printf "%s\n" "${names[@]}")" 5<<< "$(printf "%s\n" "${status[@]}")" 6<<< "$(printf "%s\n" "${genre[@]}")" 7<<< "$(printf "%s\n" "${urls[@]}")"
TOTAL_SEARCHES="${#names[@]}"
export TOTAL_SEARCHES OPTION_NAMES
}
_set_manga_variables_mangafox(){
declare option="$1"
SLUG="$(_basename "${urls[$((option-1))]}")"
NAME="${names[$((option-1))]}"
export SLUG NAME
}
_fetch_manga_details_mangafox(){
declare slug fetch_name="${2:-}" HTML&&unset VOLUMES
slug="$(_basename "${1:-$SLUG}")"
HTML="$(curl -# --compressed -L "http://m.fanfox.net/manga/$slug" -w "\n%{http_code}\n")"
_clear_line 1
[[ $HTML == *"The page you were looking for doesn"* ]]&&return 1
if [[ -n $fetch_name ]];then
NAME="$(: "$(grep 'title.*title' <<< "$HTML")"&&: "${_/<title>/}"&&printf "%s\n" "${_/<\/title>/}")"
fi
! [[ $HTML == *"Volume Not Available"* ]]&&export VOLUMES="true"
mapfile -t PAGES <<< "$(: "$(grep -oE "$slug.*c[0-9.]+[0-9]/1.html" <<< "$HTML")"&&: "${_//\/1.html/}"&&: "${_//$slug\//}"&&printf "%s\n" "${_//${VOLUMES:+\/}c0/${VOLUMES:+_}}"|sed 1d)"
mapfile -t PAGES <<< "$(_reverse "${PAGES[@]}")"
export PAGES REFERER="fanfox.net"
}
_download_chapter_mangafox(){
declare vol _page
[[ -n $VOLUMES ]]&&vol="${page//_*/}" _page="${page//*_/}"
curl -s "http://m.fanfox.net/roll_manga/$SLUG/${vol:+$vol/}c0${_page:-$page}/1.html" -w "\n%{http_code}\n"
}
_count_images_mangafox(){
TOTAL_IMAGES="$(: "$(for page in "${PAGES[@]}";do
{
grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*(jpg|png)" "$page/$page"_chapter >| "$page/$page"_images
_count < "$page/$page"_images
}&
done)"&&printf "%s\n" "$((${_//$'\n'/ + }))")"
export TOTAL_IMAGES
}
