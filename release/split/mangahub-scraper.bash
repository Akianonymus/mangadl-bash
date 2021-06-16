#!/usr/bin/env bash
_search_manga_mangahub(){
declare input="$1" num_of_search="$2" html
input="$(_url_encode "$input")"
html="$(curl -# --compressed -L "https://mangahub.io/search?q=$input&order=ALPHABET&genre=all")"
_clear_line 1
[[ -z $html || $html =~ No\ Manga\ found ]]&&return 1
html="$(: "$(grep -o "mangalist.*Popular Manga Updates" <<< "$html")"&&printf "%s\n" "${_//media-manga/$'\n'media-manga}"|grep "" -m "$((num_of_search+1))")"
mapfile -t names <<< "$(printf "%s\n" "${html//alt/$'\n'alt}"|grep -o 'alt=.*'|sed -E -e "s/ class.*//g" -e 's/^alt="//g' -e "s/\"$//g")"
_tmp="$(: "$(grep -Eo "(http|https)://mangahub.io/chapter/[a-zA-Z0-9./?=_%:-]+/chapter-[0-9]+" <<< "$html")"&&printf "%s\n" "${_//http[s]:\/\/mangahub.io\/chapter\//}")"
mapfile -t slugs <<< "$(printf "%s\n" "$_tmp"|sed -E 's/\/chapter-[0-9]+$//g')"
mapfile -t latest <<< "$(printf "%s\n" "$_tmp"|sed -E 's/.*\/chapter-//g')"
mapfile -t status <<< "$(grep -oF -e "-- -->(Ongoing)" -e "-- -->(Completed)" <<< "$html"|grep -iEo 'Ongoing|Completed')"
i=1
while read -r -u 4 name&&read -r -u 5 _latest&&read -r -u 6 _status&&read -r -u 7 _slug;do
num="$((i++))"
OPTION_NAMES+=("$num. $name
   URL: https://mangahub.io/manga/$_slug 
   Latest: Chapter $_latest
   Status: $_status")
done 4<<< "$(printf "%s\n" "${names[@]}")" 5<<< "$(printf "%s\n" "${latest[@]}")" 6<<< "$(printf "%s\n" "${status[@]}")" 7<<< "$(printf "%s\n" "${slugs[@]}")"
TOTAL_SEARCHES="${#names[@]}"
export OPTION_NAMES TOTAL_SEARCHES
}
_set_manga_variables_mangahub(){
declare option="$1"
SLUG="${slugs[$((option-1))]}"
NAME="${names[$((option-1))]}"
LATEST="${latest[$((option-1))]}"
export SLUG NAME LATEST
}
_fetch_manga_details_mangahub(){
declare fetch_name="${2:-}" html
SLUG="$(_basename "${1:-$SLUG}")"
html="$(curl -# --compressed -L "https://mangahub.io/manga/$SLUG")"
for _ in {1..2};do _clear_line 1;done
[[ $html == *"ERROR : MANGA NOT FOUND"* ]]&&return 1
[[ -n $fetch_name ]]&&NAME="$(: "$(grep -o 'title>.*</title' <<< "$html")"&&: "${_//*title>Read /}"&&printf "%s\n" "${_// Manga Online for Free<\/title*/}")"
mapfile -t PAGES <<< "$(grep -Eo "(http|https)://mangahub.io/chapter/$SLUG/chapter-[0-9]+" <<< "$html"|sed "s/.*\///g"|grep -oE '[0-9.]+')"
mapfile -t PAGES <<< "$(_reverse "${PAGES[@]}")"
mapfile -t PAGES <<< "$(_remove_array_duplicates "${PAGES[@]}")"
export SLUG PAGES NAME REFERER="mangahub.io"
}
_download_chapter_mangahub(){
curl -s -L --compressed "https://mangahub.io/chapter/$SLUG/chapter-$page" -w "\n%{http_code}\n"
}
_count_images_mangahub(){
TOTAL_IMAGES="$(: "$(for page in "${PAGES[@]}";do
{
: "$(grep -Eo '_3w1ww">[0-9]/[0-9]+' "$page/$page"_chapter|_head 1)"&&total_images="${_//*\//}"
: "$(grep -Eo "https://img.mghubcdn.com/file/imghub/$SLUG/$page/[0-9]+.(jpg|png)" "$page/$page"_chapter|_head 1)"&&extension="${_//*.jpg/jpg}"&&extension="${extension//*.png/png}"
eval printf "https://img.mghubcdn.com/file/imghub/$SLUG/$page/%s.$extension\\\n" "{1..$total_images}" >| "$page/$page"_images
_count < "$page/$page"_images
}&
done)"&&printf "%s\n" "$((${_//$'\n'/ + }))")"
export TOTAL_IMAGES
}
