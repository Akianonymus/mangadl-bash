#!/usr/bin/env bash
# Functions related to readmanhwa
# shellcheck disable=SC2016

_search_manga() {
    declare input="${1}" num_of_search="${2}"
    SEARCH_JSON="$(curl -# --compressed "https://readmanhwa.com/api/comics?nsfw=true&q=$(_url_encode "${input}")&per_page=${num_of_search}&sort=title" \
        -H "X-NSFW: true" -H "Accept-Language: en")"
    _clear_line 1
    SEARCH_JSON="${SEARCH_JSON//\}\]\},\{/$'\n'}"
    # shellcheck disable=SC2001
    SEARCH_JSON="$(sed -e "s/thumb_url.*//g" <<< "${SEARCH_JSON}")"

    if [[ ${SEARCH_JSON} =~ \"total\":0 ]]; then
        return 1
    fi

    for i in title slug alternative_title description rewritten translated speechless uploaded_at pages favorites chapters_count status thumb_url; do
        SEARCH_JSON="${SEARCH_JSON//\"${i}\"/$'\n'\"${i}\"}"
    done

    mapfile -t names <<< "$(_json_value title all all <<< "${SEARCH_JSON}")"
    mapfile -t slugs <<< "$(_json_value slug all all <<< "${SEARCH_JSON}")"
    mapfile -t latest <<< "$(_json_value uploaded_at all all <<< "${SEARCH_JSON}")"
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
    declare slug last _pages
    slug="$(_basename "${1:-${SLUG}}")"

    _print_center "justify" "Retrieving manga" " chapters.." "-"
    mapfile -t _pages <<< "$(curl -# --compressed -H "X-NSFW: true" "https://readmanhwa.com/api/comics/${slug}/chapters?nsfw=true" | grep -Eo "chapter-[0-9.]+" | grep -Eo "[0-9.]+")"
    last=${#_pages[@]}
    for ((i = last - 1; i >= 0; i--)); do
        PAGES+=("${_pages[i]}")
    done

    for _ in {1..2}; do _clear_line 1; done

    export PAGES
}

_fetch_manga_chapters() {
    declare SUCCESS_STATUS=0 ERROR_STATUS=0

    if [[ -n ${PARALLEL_DOWNLOAD} ]]; then
        dl_chapters() {
            declare dir="${1}"
            if [[ -f "${dir}/${dir}"_chapter && $(_tail 1 < "${dir}/${dir}"_chapter) =~ 200 ]]; then
                printf "1\n"
            else
                if curl -s "https://readmanhwa.com/api/comics/${SLUG}/chapter-${dir}/images?nsfw=true" \
                    -H "X-NSFW: true" \
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
                if curl -s "https://readmanhwa.com/api/comics/${SLUG}/chapter-${page}/images?nsfw=true" \
                    -H "X-NSFW: true" \
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
            for i in source_url thumbnail_url; do
                json_images="${json_images//\"${i}\"/$'\n'\"${i}\"}"
            done
            _json_value "source_url" all all <<< "${json_images//'\/'/\/}" >| "${page}/${page}"_images
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
