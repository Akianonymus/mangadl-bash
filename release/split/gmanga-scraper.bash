#!/usr/bin/env bash
_search_manga_gmanga(){
declare input="$1" num_of_search="$2" post_data search_json
post_data="$(jq -n --arg q "$input" '{query: $q, includes:["Manga"]}')"
search_json="$(curl -# --compressed https://gmanga.org/api/quick_search \
-d "$post_data" \
-e "gmanga.org" -H "Content-Type: application/json")"
[[ $search_json =~ \"data\":*\[\] ]]&&return 1
declare manga_info&&declare -g NAMES TOTAL_SEARCHES SLUGS
mapfile -t NAMES <<< "$(jq '.[].data[].title' -r <<< "$search_json")"
mapfile -t manga_info <<< "$(jq '.[].data[].id,.[].data[].latest_chapter,.[].data[].story_status' -r <<< "$search_json")"
TOTAL_SEARCHES="${#NAMES[@]}"
i=1
for name in "${NAMES[@]}";do
num="$((i++))"
[[ $num -gt $num_of_search ]]&&break
num_id="$((num-1))" id="${manga_info[$num_id]//null/Unknown}" SLUGS+=("$id")
num_latest="$((num_id+TOTAL_SEARCHES))" latest="${manga_info[$num_latest]//null/Unknown}"
num_status="$((num_latest+TOTAL_SEARCHES))" status="${manga_info[$num_status]//null/Unknown}"&&case "$status" in
2)status="Ongoing";;
3)status="Completed";;
*)status="Unknown"
esac
OPTION_NAMES+=("$num. $name
   URL: https://gmanga.org/mangas/$id
   Latest: $latest
   Status: $status")
done
export TOTAL_SEARCHES NAMES SLUGS OPTION_NAMES
}
_set_manga_variables_gmanga(){
declare option="$1"
SLUG="${SLUGS[$((option-1))]}"
NAME="${NAMES[$((option-1))]}"
export SLUG NAME
}
_fetch_manga_details_gmanga(){
declare slug="${1:-$SLUG}" fetch_name="${2:-}" json
slug="$(_basename "$slug")"
json="$(curl -L -# --compressed "https://gmanga.org/api/mangas/$slug")"
_clear_line 1
case "$json" in
*'"mangaData":null'*|*'"error":"Internal Server Error"'*)return 1
esac
[[ -n $fetch_name ]]&&NAME="$(jq '.mangaData.title' -r <<< "$json")"
_print_center "justify" "Retrieving manga" " chapters.." "-"
declare enc_json enc_data dec_data dec_json key iv
enc_json="$(curl -# -L --compressed "https://gmanga.org/api/mangas/$slug/releases")"&&_clear_line 1
enc_data="$(: "$(jq -re '.data' <<< "$enc_json")"&&printf '%s' "${_//|/$'\n'}")"||return 1
dec_data="$(sed -n 1p <<< "$enc_data")"
key="$(sed -n 4p <<< "$enc_data")"&&key="$(openssl sha256 <<< "$key")"&&key="${key//* /}"
iv="$(sed -n 3p <<< "$enc_data")"&&iv="$(openssl base64 -A -d <<< "$iv"|od -A n -t x1)"&&iv="${iv//$'\n'/}"&&iv="${iv// /}"
dec_json="$(openssl aes-256-cbc -d -K "$key" -iv "$iv" -in <(openssl base64 -A -d <<< "$dec_data") -out -)" 2>| /dev/null||return 1
mapfile -t PAGES <<< "$(jq '.rows[2].rows[][1]' -re <<< "$dec_json"|sort -V)"||return 1
_clear_line 1
export SLUG="$slug" PAGES REFERER="gmanga.org"
}
_download_chapter_gmanga(){
curl -s -L --compressed "https://gmanga.org/mangas/$SLUG/$NAME/${page:-?}/" -w "\n%{http_code}\n"
}
_count_images_gmanga(){
TOTAL_IMAGES="$(: "$(for page in "${PAGES[@]}";do
{
json="$(grep 'class="js-react-on-rails-component"' "$page/$page"_chapter|grep -oE '\{.*\}')"||:
extra_string="_webp"
images="$(jq '.readerDataAction.readerData.release.webp_pages[]' -re <<< "$json")"||{
images="$(jq '.readerDataAction.readerData.release.pages[]' -re <<< "$json")"
extra_string=""
}
release="$(jq '.readerDataAction.readerData.release.storage_key' -r <<< "$json")"
printf '%s\n' "$images"|sed "s|^|https://media.$REFERER/uploads/releases/$release/mq$extra_string/|g" >| "$page/$page"_images
_count < "$page/$page"_images
}&
done)"&&printf "%s\n" "$((${_//$'\n'/ + }))")"
export TOTAL_IMAGES
}
