#!/usr/bin/env bash
# Functions related to manganelo/mangakakalot
# shellcheck disable=SC2016

_search_manga() {
    declare input="${1// /_}" num_of_search="${2}" && declare -g SEARCH_HTML
    SEARCH_HTML="$(curl -s --compressed https://mangakakalot.com/search/story/"${input}" | grep --no-group-separator "story_name" -A 12 ${num_of_search+-m ${num_of_search}})"

    if [[ -z ${SEARCH_HTML} ]]; then
        return 1
    fi

    declare names urls latest updated && declare -g TOTAL_SEARCHES OPTION_URLS OPTION_NAMES

    mapfile -t names <<< "$(grep --no-group-separator "story_name" -A 1 <<< "${SEARCH_HTML}" | grep -E "(http|https)://[a-zA-Z0-9./?=_%:-]*" | grep -o '>.*<' | sed "s/\(^>\|<$\)//g")"
    mapfile -t urls <<< "$(grep --no-group-separator "story_name" -A 1 <<< "${SEARCH_HTML}" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*")"
    mapfile -t latest <<< "$(: "$(grep --no-group-separator "story_chapter" -A 1 <<< "${SEARCH_HTML}" | grep -v '</a>' | grep -v "story_chapter" | grep -o 'title=\".*\"')" && printf "%s\n" "${_//title=/}")"
    mapfile -t updated <<< "$(grep -o "Updated.*[0-9]" <<< "${SEARCH_HTML}")"

    i=1
    OPTION_URLS="$(
        for line in "${urls[@]}"; do
            num="$((i++))"
            _urls+="${num}. ${line}
" > /dev/null
        done
        printf "%s\n" "${_urls}"
    )"

    i=1
    OPTION_NAMES="$(
        while read -r -u 4 name && read -r -u 5 _latest && read -r -u 6 _update; do
            num="$((i++))"
            list+="${num}. ${name}
   Latest: ${_latest}
   ${_update}

"
        done 4<<< "$(printf "%s\n" "${names[@]}")" 5<<< "$(printf "%s\n" "${latest[@]}")" 6<<< "$(printf "%s\n" "${updated[@]}")"
        printf "%s\n" "${list}"
    )"

    TOTAL_SEARCHES="${#names[@]}"
    export TOTAL_SEARCHES
}

_set_manga_variables() {
    option="${1}"

    URL="$(: "$(grep -F "${option}. " <<< "${OPTION_URLS}")" && printf "%s\n" "${_/${option}. /}")"

    NAME="$(: "$(grep -F "${option}. " <<< "${OPTION_NAMES}")" && printf "%s\n" "${_/${option}. /}")"

    export URL NAME
}

_fetch_manga_details() {
    declare url="${1:-${URL}}" fetch_name="${2:-}" HTML
    HTML="$(curl -s -# --compressed -L "${url}" -w "\n%{http_code}\n")"

    if [[ ${HTML} = *"Sorry, the page you have requested cannot be found"* ]]; then
        return 1
    fi

    if [[ -n ${fetch_name} ]]; then
        NAME="$(grep -F h1 <<< "${HTML}" | sed "s/\(<h1>\|<\/h1>\)//g")"
    fi

    if [[ ${url} =~ mangakakalot ]]; then
        mapfile -t URL_PAGES <<< "$(grep -F 'div class="row"' -A 1 <<< "${HTML}" | grep -Eo "(http|https)://mangakakalot[a-zA-Z0-9./?=_%:-]*")"
    else
        mapfile -t URL_PAGES <<< "$(grep -F chapter-name <<< "${HTML}" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*")"
    fi
    mapfile -t URL_PAGES <<< "$(_reverse "${URL_PAGES[@]}")"
    mapfile -t PAGES <<< "$(printf "%s\n" "${URL_PAGES[@]}" | sed "s/.*\///g" | grep -oE '[0-9.]+')"

    export PAGES
}

_fetch_manga_chapters() {
    SUCCESS_STATUS=0 ERROR_STATUS=0

    if [[ -n ${ASK_RANGE} ]]; then
        : "https.*_($(printf "%s|" "${PAGES[@]}"))" && regex="${_//\|\)/\)}"
        mapfile -t URL_PAGES <<< "$(printf "%s\n" "${URL_PAGES[@]}" | grep -Exo ''"${regex}"'')"
    fi

    if [[ -n ${PARALLEL_DOWNLOAD} ]]; then
        dl_chapters() {
            declare page url="${1}"
            page="$(sed "s/.*\///" <<< "${1}" | grep -oE '[0-9.]+')"
            if [[ -f "${page}/${page}"_chapter && $(_tail 1 < "${page}/${page}"_chapter) =~ 200 ]]; then
                printf "1\n"
            else
                if curl -s -L --compressed "${url}" -w "\n%{http_code}\n" >| "${page}/${page}"_chapter; then
                    printf "1\n"
                else
                    printf "2\n" 1>&2
                fi
            fi
        }

        { [[ ${NO_OF_PARALLEL_JOBS} -gt ${#PAGES[@]} ]] && NO_OF_PARALLEL_JOBS="${#PAGES[@]}"; } || :

        export -f dl_chapters _tail && export URL
        printf "%s\n" "${URL_PAGES[@]}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS}" -i bash -c '
        dl_chapters "{}" 
        ' 1> "${TMPFILE}".success 2> "${TMPFILE}".error &

        _wait_func() {
            declare string
            string="$(jobs)"
            { [[ ${string// /} =~ unning.*xargs ]] && return 0; } || return 1
        }

        _newline "\n"

        until [[ -f "${TMPFILE}".success || -f "${TMPFILE}".error ]]; do
            _bash_sleep 0.5
        done

        until ! _wait_func; do
            SUCCESS_STATUS="$(_count < "${TMPFILE}".success)"
            ERROR_STATUS="$(_count < "${TMPFILE}".error)"
            _bash_sleep 1
            if [[ ${TOTAL_STATUS} != "$((SUCCESS_STATUS + ERROR_STATUS))" ]]; then
                _clear_line 1
                _print_center "justify" "${SUCCESS_STATUS} success" " | ${ERROR_STATUS} failed" "="
            fi
            TOTAL_STATUS="$((SUCCESS_STATUS + ERROR_STATUS))"
        done

        rm -f "${TMPFILE}".success "${TMPFILE}".error
    else
        _newline "\n"

        for url in "${URL_PAGES[@]}"; do
            page="$(sed "s/.*\///" <<< "${url}" | grep -oE '[0-9.]+')"
            if [[ -f "${page}/${page}"_chapter && $(_tail 1 < "${page}/${page}"_chapter) = 200 ]]; then
                SUCCESS_STATUS="$((SUCCESS_STATUS + 1))"
            else
                if curl -s -L --compressed "${url}" -w "\n%{http_code}\n" >| "${page}/${page}"_chapter; then
                    SUCCESS_STATUS="$((SUCCESS_STATUS + 1))"
                else
                    ERROR_STATUS="$((ERROR_STATUS + 1))"
                fi
            fi
            _clear_line 1 1>&2
            _print_center "justify" "${SUCCESS_STATUS} success" " | ${ERROR_STATUS} failed" "=" 1>&2
        done
    fi
    _clear_line 1
}

_count_images() {
    TOTAL_IMAGES="$(: "$(for page in "${PAGES[@]}"; do
        {
            grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*chapter_[a-zA-Z0-9./?=_%:-]*.(jpg|png)" "${page}/${page}"_chapter >| "${page}/${page}"_images
            _count < "${page}/${page}"_images
        } &
    done)" && printf "%s\n" "$((${_//$'\n'/ + }))")"
    export TOTAL_IMAGES
}

_download_images() {
    SUCCESS_STATUS=0 ERROR_STATUS=0
    if [[ -n ${PARALLEL_DOWNLOAD} ]]; then

        { [[ ${NO_OF_PARALLEL_JOBS} -gt ${#PAGES[@]} ]] && NO_OF_PARALLEL_JOBS="${#PAGES[@]}"; } || :

        printf "%s\n" "${PAGES[@]}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS}" -i \
            wget --referer="manganelo.com" -P "{}" -c -i "{}/{}"_images &> "${TMPFILE}".log &
        _wait_func() {
            declare string
            string="$(jobs)"
            { [[ ${string// /} =~ unning.*xargs ]] && return 0; } || return 1
        }

        until [[ -f "${TMPFILE}".log ]]; do
            _bash_sleep 0.5
        done

        until ! _wait_func; do
            SUCCESS_STATUS="$(grep -ic 'retrieved\|saved' "${TMPFILE}".log)"
            ERROR_STATUS="$(grep -ic 'ERROR 404' "${TMPFILE}".log)"
            _bash_sleep 1
            if [[ ${TOTAL_STATUS} != "$((SUCCESS_STATUS + ERROR_STATUS))" ]]; then
                _clear_line 1
                _print_center "justify" "${SUCCESS_STATUS} success" " | ${ERROR_STATUS} failed" "="
            fi
            TOTAL_STATUS="$((SUCCESS_STATUS + ERROR_STATUS))"
        done

        rm -f "${TMPFILE}".success "${TMPFILE}".error
    else
        for page in "${PAGES[@]}"; do
            log="$(wget --referer="manganelo.com" -P "${page}" -c -i "${page}/${page}"_images 2>&1)"
            SUCCESS_STATUS="$(($(grep -ic 'retrieved\|saved' <<< "${log}") + SUCCESS_STATUS))"
            ERROR_STATUS="$(($(grep -ic 'ERROR 404' <<< "${log}") + ERROR_STATUS))"
            _clear_line 1 1>&2
            _print_center "justify" "${SUCCESS_STATUS} success" " | ${ERROR_STATUS} failed" "=" 1>&2
        done
    fi

    _clear_line 1

    shopt -s extglob
    # shellcheck disable=SC2086
    IMAGES="$(_PAGES="$(printf "%s/*+(jpg|png)\n" "${PAGES[@]}")" && printf "%b\n" ${_PAGES})"
    # shellcheck disable=SC2086
    TOTAL_IMAGES_SIZE="$(
        : "$(wc -c ${IMAGES} | _tail 1 | grep -Eo '[0-9]'+)"
        printf "%s\n" "$(_bytes_to_human "${_}")"
    )"
    export TOTAL_IMAGES_SIZE
    shopt -u extglob

}
