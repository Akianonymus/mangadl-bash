#!/usr/bin/env bash
# Functions related to mangahub
# shellcheck disable=SC2016

_search_manga() {
    declare input="${1}" num_of_search="${2}" post_data
    post_data='{"query":"{search(x:m01,q:\"'${input}'\",genre:\"all\",mod:ALPHABET'${num_of_search:+,limit:${num_of_search}}'){rows{title,slug,status,latestChapter}}}"}'
    SEARCH_JSON="$(curl -# --compressed https://api.mghubcdn.com/graphql \
        -d "${post_data}" \
        -H "Content-Type: application/json")"
    _clear_line 1
    SEARCH_JSON="${SEARCH_JSON//\},\{/$'\n'}" && SEARCH_JSON="${SEARCH_JSON//\}\]/$'\n'}"

    if ! [[ ${SEARCH_JSON} =~ title ]]; then
        return 1
    fi

    for i in title slug status latestChapter; do
        SEARCH_JSON="${SEARCH_JSON//\"${i}\"/$'\n'\"${i}\"}"
    done

    mapfile -t names <<< "$(_json_value title all all <<< "${SEARCH_JSON}")"
    mapfile -t slugs <<< "$(_json_value slug all all <<< "${SEARCH_JSON}")"
    mapfile -t latest <<< "$(_json_value latestChapter all all <<< "${SEARCH_JSON}")"
    mapfile -t status <<< "$(_json_value status all all <<< "${SEARCH_JSON}")"

    i=1
    while read -r -u 4 name && read -r -u 5 _latest && read -r -u 6 _status; do
        num="$((i++))"
        OPTION_NAMES+=("${num}. ${name}
   Latest: ${_latest}
   Status: ${_status}")
    done 4<<< "$(printf "%s\n" "${names[@]}")" 5<<< "$(printf "%s\n" "${latest[@]}")" 6<<< "$(printf "%s\n" "${status[@]}")"

    TOTAL_SEARCHES="${#names[@]}"

    export OPTION_NAMES TOTAL_SEARCHES
}

_set_manga_variables() {
    declare option="${1}"

    SLUG="${slugs[$((option - 1))]}"

    NAME="${names[$((option - 1))]}"

    LATEST="${latest[$((option - 1))]}"

    export NAME LATEST
}

_fetch_manga_details() {
    declare slug fetch_name="${2:-}" json
    slug="$(_basename "${1:-${SLUG}}")"

    _print_center "justify" "Retrieving mangaid.." "-"
    json="$(curl -# --compressed https://api.mghubcdn.com/graphql \
        -d '{"query":"{chapter(x:m01,slug:\"'"${slug}"'\",number:'"${LATEST:-1}"'){mangaID'${fetch_name:+,manga\{title\}}'}}"}' \
        -H "Content-Type: application/json")"
    for _ in {1..2}; do _clear_line 1; done

    MANGAID="$(_regex "${json}" '[0-9.]+' 0)"

    if [[ -n ${fetch_name} ]]; then
        NAME="$(: "${json//*title\":\"/}" && printf "%s\n" "${_/\"\}*/}")"
    fi

    _print_center "justify" "Retrieving manga" " chapters.." "-"
    mapfile -t PAGES <<< "$(curl -# --compressed https://api.mghubcdn.com/graphql \
        -d '{"query":"{chaptersByManga(mangaID:'"${MANGAID}"'){number}}"}' \
        -H "Content-Type: application/json" | grep -Eo "[0-9.]+")"
    for _ in {1..2}; do _clear_line 1; done

    export MANGAID PAGES NAME
}

_fetch_manga_chapters() {
    declare SUCCESS_STATUS=0 ERROR_STATUS=0

    if [[ -n ${PARALLEL_DOWNLOAD} ]]; then
        dl_chapters() {
            declare dir="${1}"
            if [[ -f "${page}/${page}"_chapter && $(_tail 1 < "${page}/${page}"_chapter) =~ 200 ]]; then
                printf "1\n"
            else
                if curl -s -L --compressed https://api.mghubcdn.com/graphql \
                    -d '{"query":"{chapter(x:m01,slug:\"'"${SLUG}"'\",number:'"${dir}"'){pages}}"}' \
                    -H "Content-Type: application/json" -w "\n%{http_code}\n" >| "${dir}/${dir}"_chapter; then
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
                if curl -s --compressed https://api.mghubcdn.com/graphql \
                    -d '{"query":"{chapter(x:m01,slug:\"'"${SLUG}"'\",number:'"${page}"'){pages}}"}' \
                    -H "Content-Type: application/json" \
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
            json_images="$(< "${page}/${page}"_chapter)"
            printf "%b\n" "${json_images//:\\\"/$"\n"https://img.mghubcdn.com/file/imghub/}" | grep -Eo ".*(jpg|png)+" >| "${page}/${page}"_images
            _count < "${page}/${page}"_images
        } &
    done)" && printf "%s\n" "$((${_//$'\n'/ + }))")"
    export TOTAL_IMAGES
}

_download_images() {
    declare SUCCESS_STATUS=0 ERROR_STATUS=0
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
    export TOTAL_IMAGES_SIZE IMAGES
    shopt -u extglob

}
