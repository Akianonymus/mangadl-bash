#!/usr/bin/env bash
# Functions related to manganelo/mangakakalot
# shellcheck disable=SC2016

_search_manga_manganelo() {
    declare input="${1// /_}" num_of_search="${2}"
    SEARCH_HTML="$(curl -# --compressed https://mangakakalot.com/search/story/"${input}")"
    _clear_line 1

    [[ ${SEARCH_HTML} != *"story_name"* ]] && return 1

    SEARCH_HTML="$(grep "story_name" -A 12 ${num_of_search:+-m ${num_of_search}} <<< "${SEARCH_HTML}")"

    mapfile -t names <<< "$(grep "story_name" -A 1 <<< "${SEARCH_HTML}" | grep -E "(http|https)://[a-zA-Z0-9./?=_%:-]*" | grep -o '>.*<' | sed "s/\(^>\|<$\)//g")"
    mapfile -t urls <<< "$(grep "story_name" -A 1 <<< "${SEARCH_HTML}" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*")"
    mapfile -t latest <<< "$(: "$(grep "story_chapter" -A 1 <<< "${SEARCH_HTML}" | grep -v '</a>\|story_chapter' | grep -o 'title=\".*\"')" && printf "%s\n" "${_//title=/}")"
    mapfile -t updated <<< "$(grep -o "Updated.*[0-9]" <<< "${SEARCH_HTML}")"

    i=1
    while read -r -u 4 name && read -r -u 5 _latest && read -r -u 6 _update && read -r -u 7 url; do
        num="$((i++))"
        OPTION_NAMES+=("${num}. ${name}
   URL: ${url}
   Latest: ${_latest}
   ${_update}")
    done 4<<< "$(printf "%s\n" "${names[@]}")" 5<<< "$(printf "%s\n" "${latest[@]}")" 6<<< "$(printf "%s\n" "${updated[@]}")" 7<<< "$(printf "%s\n" "${urls[@]}")"

    TOTAL_SEARCHES="${#names[@]}"
    export TOTAL_SEARCHES OPTION_NAMES
}

_set_manga_variables_manganelo() {
    declare option="${1}"

    URL="${urls[$((option - 1))]}"
    NAME="${names[$((option - 1))]}"

    export URL NAME
}

_fetch_manga_details_manganelo() {
    declare url="${1:-${URL}}" fetch_name="${2:-}" HTML

    HTML="$(curl -# --compressed -L "${url}" -w "\n%{http_code}\n")"
    _clear_line 1

    [[ ${HTML} = *"Sorry, the page you have requested cannot be found"* ]] && return 1

    if [[ -n ${fetch_name} ]]; then
        NAME="$(: "$(_regex "${HTML}" 'h1.*h1' 0)" && : "${_/h1>/}" && printf "%s\n" "${_/<\/h1/}")"
    fi

    if [[ ${url} =~ mangakakalot ]]; then
        mapfile -t URL_PAGES <<< "$(grep -F 'div class="row"' -A 1 <<< "${HTML}" | grep -Eo "(http|https)://mangakakalot[a-zA-Z0-9./?=_%:-]*")"
    else
        mapfile -t URL_PAGES <<< "$(grep -F chapter-name <<< "${HTML}" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*")"
    fi
    mapfile -t URL_PAGES <<< "$(_reverse "${URL_PAGES[@]}")"
    mapfile -t PAGES <<< "$(printf "%s\n" "${URL_PAGES[@]}" | sed "s/.*\///g" | grep -oE '[0-9.]+')"
    CHAPTER_STRING="$(_basename "${URL_PAGES[0]//[0-9.]/}")"
    MANGA_URL="${URL_PAGES[0]/${CHAPTER_STRING}*/}"

    export CHAPTER_STRING PAGES MANGA_URL REFERER="manganelo.com"
}

_download_chapter_manganelo() {
    curl -s -L --compressed "${MANGA_URL}${CHAPTER_STRING}${page}" -w "\n%{http_code}\n"
}

_count_images_manganelo() {
    TOTAL_IMAGES="$(: "$(for page in "${PAGES[@]}"; do
        {
            grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*chapter_[a-zA-Z0-9./?=_%:-]*.(jpg|png)" "${page}/${page}"_chapter >| "${page}/${page}"_images
            _count < "${page}/${page}"_images
        } &
    done)" && printf "%s\n" "$((${_//$'\n'/ + }))")"
    export TOTAL_IMAGES
}
