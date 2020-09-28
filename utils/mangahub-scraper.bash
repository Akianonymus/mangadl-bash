#!/usr/bin/env bash
# Functions related to mangahub
# shellcheck disable=SC2016,SC2001

_search_manga_mangahub() {
    declare input="${1}" num_of_search="${2}" post_data
    post_data='{"query":"{search(x:m01,q:\"'${input}'\",genre:\"all\",mod:ALPHABET'${num_of_search:+,limit:${num_of_search}}'){rows{title,slug,status,latestChapter}}}"}'
    SEARCH_JSON="$(curl -# --compressed https://api.mghubcdn.com/graphql \
        -d "${post_data}" \
        -H "Content-Type: application/json")"
    _clear_line 1
    SEARCH_JSON="${SEARCH_JSON//\},\{/$'\n'}" && SEARCH_JSON="${SEARCH_JSON//\}\]/$'\n'}"
    SEARCH_JSON="$(sed -e "s/tags.*//g" <<< "${SEARCH_JSON}")"

    ! [[ ${SEARCH_JSON} =~ title ]] && return 1

    for i in title slug status latestChapter; do
        SEARCH_JSON="${SEARCH_JSON//\"${i}\"/$'\n'\"${i}\"}"
    done

    mapfile -t names <<< "$(_json_value title all all <<< "${SEARCH_JSON}")"
    mapfile -t slugs <<< "$(_json_value slug all all <<< "${SEARCH_JSON}")"
    mapfile -t latest <<< "$(_json_value latestChapter all all <<< "${SEARCH_JSON}")"
    mapfile -t status <<< "$(_json_value status all all <<< "${SEARCH_JSON}")"

    i=1
    while read -r -u 4 name && read -r -u 5 _latest && read -r -u 6 _status && read -r -u 7 _slug; do
        num="$((i++))"
        OPTION_NAMES+=("${num}. ${name}
   URL: https://mangahub.io/manga/${_slug} 
   Latest: ${_latest}
   Status: ${_status}")
    done 4<<< "$(printf "%s\n" "${names[@]}")" 5<<< "$(printf "%s\n" "${latest[@]}")" 6<<< "$(printf "%s\n" "${status[@]}")" 7<<< "$(printf "%s\n" "${slugs[@]}")"

    TOTAL_SEARCHES="${#names[@]}"

    export OPTION_NAMES TOTAL_SEARCHES
}

_set_manga_variables_mangahub() {
    declare option="${1}"

    SLUG="${slugs[$((option - 1))]}"
    NAME="${names[$((option - 1))]}"
    LATEST="${latest[$((option - 1))]}"

    export SLUG NAME LATEST
}

_fetch_manga_details_mangahub() {
    declare slug fetch_name="${2:-}" json
    slug="$(_basename "${1:-${SLUG}}")"

    _print_center "justify" "Retrieving mangaid.." "-"
    json="$(curl -# --compressed https://api.mghubcdn.com/graphql \
        -d '{"query":"{chapter(x:m01,slug:\"'"${slug}"'\",number:'"${LATEST:-1}"'){mangaID'${fetch_name:+,manga\{title\}}'}}"}' \
        -H "Content-Type: application/json")"
    for _ in {1..2}; do _clear_line 1; done

    [[ ${json} = *"Cannot read property"* ]] && return 1

    MANGAID="$(_regex "${json}" '[0-9.]+' 0)"

    [[ -n ${fetch_name} ]] && NAME="$(: "${json//*title\":\"/}" && printf "%s\n" "${_/\"\}*/}")"

    _print_center "justify" "Retrieving manga" " chapters.." "-"
    mapfile -t PAGES <<< "$(curl -# --compressed https://api.mghubcdn.com/graphql \
        -d '{"query":"{chaptersByManga(mangaID:'"${MANGAID}"'){number}}"}' \
        -H "Content-Type: application/json" | grep -Eo "[0-9.]+")"
    for _ in {1..2}; do _clear_line 1; done

    export MANGAID PAGES NAME REFERER="mangahub.io"
}

_download_chapter_mangahub() {
    curl -s -L --compressed https://api.mghubcdn.com/graphql \
        -d '{"query":"{chapter(x:m01,slug:\"'"${SLUG}"'\",number:'"${page}"'){pages}}"}' \
        -H "Content-Type: application/json" -w "\n%{http_code}\n"
}

_count_images_mangahub() {
    TOTAL_IMAGES="$(: "$(for page in "${PAGES[@]}"; do
        {
            json_images="$(< "${page}/${page}"_chapter)"
            printf "%b\n" "${json_images//:\\\"/$"\n"https://img.mghubcdn.com/file/imghub/}" | grep -Eo ".*(jpg|png)+" >| "${page}/${page}"_images
            _count < "${page}/${page}"_images
        } &
    done)" && printf "%s\n" "$((${_//$'\n'/ + }))")"
    export TOTAL_IMAGES
}
