#!/usr/bin/env bash
# Functions related to mangafox
# shellcheck disable=SC2016

_search_manga() {
    declare input="${1// /+}" num_of_search="${2}" && declare -g SEARCH_HTML
    SEARCH_HTML="$(curl -# --compressed http://m.fanfox.net/search?k="${input}")"
    _clear_line 1

    if [[ ${SEARCH_HTML} = *"No Manga Series."* ]]; then
        return 1
    fi

    SEARCH_HTML="$(grep --no-group-separator "post-one clearfix" -A 8 ${num_of_search:+-m ${num_of_search}} <<< "${SEARCH_HTML}")"

    mapfile -t names <<< "$(grep '"title"' <<< "${SEARCH_HTML}" | grep -o '>.*<' | sed "s/\(^>\|<$\)//g")"
    mapfile -t urls <<< "$(grep 'href="' <<< "${SEARCH_HTML}" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*")"
    mapfile -t status <<< "$(: "$(grep -Eo "Status:.*(Completed|Ongoing)" <<< "${SEARCH_HTML}")" && : "${_//Status: /}" && printf "%s\n" "${_//Status:/}")"
    mapfile -t genre <<< "$(: "$(grep --no-group-separator 'Status:' -B 1 <<< "${SEARCH_HTML}" | grep -v 'Status:')" && : "${_//<p>/}" && printf "%s\n" "${_//<\/p>/}")"

    i=1
    while read -r -u 4 name && read -r -u 5 _status && read -r -u 6 _genre; do
        num="$((i++))"
        OPTION_NAMES+=("${num}. ${name}
   Status: ${_status}
   Genre: ${_genre}")
    done 4<<< "$(printf "%s\n" "${names[@]}")" 5<<< "$(printf "%s\n" "${status[@]}")" 6<<< "$(printf "%s\n" "${genre[@]}")"

    TOTAL_SEARCHES="${#names[@]}"
    export TOTAL_SEARCHES OPTION_NAMES
}

_set_manga_variables() {
    declare option="${1}"

    SLUG="$(_basename "${urls[$((option - 1))]}")"

    NAME="${names[$((option - 1))]}"

    export SLUG NAME
}

_fetch_manga_details() {
    declare slug fetch_name="${2:-}" HTML
    slug="$(_basename "${1:-${SLUG}}")"

    HTML="$(curl -# --compressed -L "http://m.fanfox.net/manga/${slug}" -w "\n%{http_code}\n")"
    _clear_line 1

    if [[ ${HTML} =~ "The page you were looking for doesn" ]]; then
        return 1
    fi

    if [[ -n ${fetch_name} ]]; then
        NAME="$(: "$(grep 'title.*title' <<< "${HTML}")" && : "${_/<title>/}" && printf "%s\n" "${_/<\/title>/}")"
    fi

    mapfile -t PAGES <<< "$(: "$(grep -oE 'c[0-9.]+[0-9]/1.html' <<< "${HTML}")" && : "${_//\/1.html/}" && printf "%s\n" "${_//c0/}" | sed 1d)"
    mapfile -t PAGES <<< "$(_reverse "${PAGES[@]}")"

    export PAGES
}

_fetch_manga_chapters() {
    SUCCESS_STATUS=0 ERROR_STATUS=0

    if [[ -n ${PARALLEL_DOWNLOAD} ]]; then
        dl_chapters() {
            declare dir="${1}"
            if [[ -f "${dir}/${dir}"_chapter && $(_tail 1 < "${dir}/${dir}"_chapter) =~ 200 ]]; then
                printf "1\n"
            else
                if curl -s "http://m.fanfox.net/roll_manga/${SLUG}/c0${dir}/1.html" \
                    -w "\n%{http_code}\n" >| "${dir}/${dir}"_chapter; then
                    printf "1\n"
                else
                    printf "2\n" 1>&2
                fi
            fi
        }

        { [[ ${NO_OF_PARALLEL_JOBS} -gt ${#PAGES[@]} ]] && NO_OF_PARALLEL_JOBS="${#PAGES[@]}"; } || :

        export -f dl_chapters _tail && export SLUG
        printf "%s\n" "${PAGES[@]}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS}" -i bash -c '
        dl_chapters "{}" 
        ' 1> "${TMPFILE}".success 2> "${TMPFILE}".error &

        _newline "\n"

        until [[ -f "${TMPFILE}".success || -f "${TMPFILE}".error ]]; do
            _bash_sleep 0.5
        done

        until [[ -z $(jobs -p) ]]; do
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

        for page in "${PAGES[@]}"; do
            if [[ -f "${page}/${page}"_chapter && $(_tail 1 < "${page}/${page}"_chapter) =~ 200 ]]; then
                SUCCESS_STATUS="$((SUCCESS_STATUS + 1))"
            else
                if curl -s "http://m.fanfox.net/roll_manga/${SLUG}/c0${page}/1.html" \
                    -w "\n%{http_code}\n" >| "${page}/${page}"_chapter; then
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
            grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*(jpg|png)" "${page}/${page}"_chapter >| "${page}/${page}"_images
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
            wget -P "{}" -c -i "{}/{}"_images &> "${TMPFILE}".log &

        until [[ -f "${TMPFILE}".log ]]; do
            _bash_sleep 0.5
        done

        until [[ -z $(jobs -p) ]]; do
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
            log="$(wget -P "${page}" -c -i "${page}/${page}"_images 2>&1)"
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
