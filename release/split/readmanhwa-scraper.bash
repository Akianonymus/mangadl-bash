#!/usr/bin/env bash
_search_manga_readmanhwa(){
declare input="$1" num_of_search="$2"
SEARCH_JSON="$(curl -# --compressed "https://readmanhwa.com/api/comics?nsfw=true&q=$(_url_encode "$input")&per_page=$num_of_search&sort=title" \
-H "X-NSFW: true" -H "Accept-Language: en")"
_clear_line 1
SEARCH_JSON="${SEARCH_JSON//\}\]\},\{/$'\n'}"
SEARCH_JSON="$(sed -e "s/thumb_url.*//g" <<< "$SEARCH_JSON")"
[[ $SEARCH_JSON =~ \"total\":0 ]]&&return 1
for i in title slug alternative_title description rewritten translated speechless uploaded_at pages favorites chapters_count status thumb_url;do
SEARCH_JSON="${SEARCH_JSON//\"$i\"/$'\n'\"$i\"}"
done
mapfile -t names <<< "$(_json_value title all all <<< "$SEARCH_JSON")"
mapfile -t slugs <<< "$(_json_value slug all all <<< "$SEARCH_JSON")"
mapfile -t latest <<< "$(_json_value uploaded_at all all <<< "$SEARCH_JSON")"
mapfile -t status <<< "$(_json_value status all all <<< "$SEARCH_JSON")"
i=1
while read -r -u 4 name&&read -r -u 5 _latest&&read -r -u 6 _status&&read -r -u 7 _slug;do
num="$((i++))"
OPTION_NAMES+=("$num. $name
   URL: https://readmanhwa.com/comics/$_slug
   Latest: $_latest
   Status: $_status")
done 4<<< "$(printf "%s\n" "${names[@]}")" 5<<< "$(printf "%s\n" "${latest[@]}")" 6<<< "$(printf "%s\n" "${status[@]}")" 7<<< "$(printf "%s\n" "${slugs[@]}")"
TOTAL_SEARCHES="${#names[@]}"
export OPTION_NAMES TOTAL_SEARCHES
}
_set_manga_variables_readmanhwa(){
declare option="$1"
SLUG="${slugs[$((option-1))]}"
NAME="${names[$((option-1))]}"
LATEST="${latest[$((option-1))]}"
export NAME LATEST
}
_fetch_manga_details_readmanhwa(){
declare slug last _pages
slug="$(_basename "${1:-$SLUG}")"
_print_center "justify" "Retrieving manga" " chapters.." "-"
mapfile -t _pages <<< "$(curl -# --compressed -H "X-NSFW: true" "https://readmanhwa.com/api/comics/$slug/chapters?nsfw=true"|grep -Eo "chapter-[0-9.]+"|grep -Eo "[0-9.]+")"
[[ -z ${_pages[*]} ]]&&return 1
last=${#_pages[@]}
for ((i=last-1; i>=0; i--));do
PAGES+=("${_pages[i]}")
done
for _ in {1..2};do _clear_line 1;done
export PAGES REFERER="readmanhwa.com"
}
_download_chapter_readmanhwa(){
curl -s "https://readmanhwa.com/api/comics/$SLUG/chapter-$page/images?nsfw=true" -H "X-NSFW: true" -w "\n%{http_code}\n"
}
_count_images_readmanhwa(){
TOTAL_IMAGES="$(: "$(for page in "${PAGES[@]}";do
{
json_images="$(< "$page/$page"_chapter)"
for i in source_url thumbnail_url;do
json_images="${json_images//\"$i\"/$'\n'\"$i\"}"
done
_json_value "source_url" all all <<< "${json_images//'\/'/\/}" >| "$page/$page"_images
_count < "$page/$page"_images
}&
done)"&&printf "%s\n" "$((${_//$'\n'/ + }))")"
export TOTAL_IMAGES
}
