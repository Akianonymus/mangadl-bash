#!/usr/bin/env bash
# Functions related to manga4life
# shellcheck disable=SC2016

_search_manga_manga4life() {
    # this is where manga list is stored
    declare file_path="${HOME}/.manga4life.list"
    fetch="true"
    # do a cache of 12 hrs ( 43200 seconds )
    # taken from here: https://github.com/KevCui/manga2mobi/blob/139a7eb7cfbef9a64146ba63c7cbe990c0d0f280/lib/mangalife.sh#L9
    if [[ -f ${file_path} ]] &&
        grep -q "vm.Directory" "${file_path}" &&
        [[ $(($(date -r "${file_path}" +%s) + 43200)) -gt $(printf "%(%s)T\\n" "-1") ]]; then
        fetch="false"
    fi

    [[ ${fetch} = "true" ]] && {
        _print_center "justify" "Fetching manga4life manga list.." "-"
        chmod u+w -f "${file_path}"
        curl -sL --compressed "https://manga4life.com/search/" -o "${file_path}" || {
            printf "%s\n" "Error: Couldn't fetch manga list." 1>&2 && return 1
        }
        _clear_line 1
        # format the fetched list
        # generated with below code, ugly but works
        # for j in i o s ss ps t v vm y a al lt ls g h; do
        # printf " %s "  ' -e "s/\"'${j}'\"/\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\"'${j}'\"/g"'
        # done
        manga_list="$(grep -o "vm.Directory = .*" "${file_path}" | sed -e \
            "s/\"i\"/\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\"i\"/g" \
            -e "s/\"o\"/\n\"o\"/g" \
            -e "s/\"s\"/\n\"s\"/g" \
            -e "s/\"ss\"/\n\"ss\"/g" \
            -e "s/\"ps\"/\n\"ps\"/g" \
            -e "s/\"t\"/\n\"t\"/g" \
            -e "s/\"v\"/\n\"v\"/g" \
            -e "s/\"vm\"/\n\"vm\"/g" \
            -e "s/\"y\"/\n\"y\"/g" \
            -e "s/\"a\"/\n\"a\"/g" \
            -e "s/\"al\"/\n\"al\"/g" \
            -e "s/\"lt\"/\n\"lt\"/g" \
            -e "s/\"l\"/\n\"l\"/g" \
            -e "s/\"ls\"/\n\"ls\"/g" \
            -e "s/\"g\"/\n\"g\"/g" \
            -e "s/\"h\"/\n\"h\"/g")"
        printf "%s\n" "${manga_list}" >| "${file_path}"
    }

    declare input="${1}" num_of_search="${2}"
    if search_results="$(grep -i -A 16 "\"s\".*${input}" "${file_path}" ${num_of_search:+-m ${num_of_search}})"; then
        mapfile -t slugs <<< "$(grep -i -B 1 "\"s\".*${input}" "${file_path}" ${num_of_search:+-m ${num_of_search}} | grep '"i"' | sed -e "s/^\"i\"\:\"//g" -e "s/\",$//g")"
        mapfile -t names <<< "$(grep '"s"' <<< "${search_results}" | sed -e "s/^\"s\"\:\"//g" -e "s/\",$//g")"
        mapfile -t status <<< "$(grep '"ss"' <<< "${search_results}" | sed -e "s/^\"ss\"\:\"//g" -e "s/\",$//g")"
        mapfile -t latest <<< "$(grep '"l"' <<< "${search_results}" | sed -e "s/^\"l\"\:\"//g" -e "s/\",$//g")"
        mapfile -t updated <<< "$(grep '"ls"' <<< "${search_results}" | sed -e "s/^\"ls\"\:\"//g" -e "s/T.*//g")"
        i=1
        while read -r -u 4 name && read -r -u 5 _latest && read -r -u 6 _update && read -r -u 7 slug && read -r -u 8 _status; do
            num="$((i++))"
            # latest chapter sometimes mess up, idk why the data is like that
            OPTION_NAMES+=("${num}. ${name}
   URL: https://manga4life.com/manga/${slug}
   Status: ${_status}
   Latest: Chapter $(: "${_latest#[0-9]}" && printf "%s\n" "${_%0}" | grep -Eo '[1-9]+[0-9]+$' || printf "%s\n" "not known"), ${_update}")
        done 4<<< "$(printf "%s\n" "${names[@]}")" 5<<< "$(printf "%s\n" "${latest[@]}")" 6<<< "$(printf "%s\n" "${updated[@]}")" 7<<< "$(printf "%s\n" "${slugs[@]}")" 8<<< "$(printf "%s\n" "${status[@]}")"
    else
        return 1
    fi
    TOTAL_SEARCHES="${#slugs[@]}"
    export TOTAL_SEARCHES OPTION_NAMES
}

_set_manga_variables_manga4life() {
    declare option="${1}"

    SLUG="${slugs[$((option - 1))]}"
    NAME="${names[$((option - 1))]}"

    export SLUG NAME
}

_fetch_manga_details_manga4life() {
    declare slug fetch_name="${2:-}" HTML url
    slug="$(_basename "${1:-${SLUG}}")" && SLUG="${slug}"
    url="https://manga4life.com/manga/${slug}"

    HTML="$(curl -# --compressed "${url}" -w "\n%{http_code}\n")"
    _clear_line 1

    [[ ${HTML} = *"We're sorry, the page you"* ]] && return 1

    if [[ -n ${fetch_name} ]]; then
        NAME="$(: "$(grep -o 'h1>.*</h1' <<< "${HTML}")" && : "${_//*h1>/}" && printf "%s\n" "${_//<\/h1*/}")"
    fi

    mapfile -t _PAGES <<< "$(grep 'vm.Chapters = ' <<< "${HTML}" | grep -Eo '[0-9]+{6}')"
    # create pages array
    mapfile -t PAGES <<< "$(printf "%s\n" "${_PAGES[@]}" | sed -E -e "s/^[0-9]//g" -e "s/[1-9]$/.&/g" -e "s/0$//g" -e "s/^0*//g" | grep -Eo '[0-9.]+')"
    # create index var
    while read -r -u 4 long_page && read -r -u 5 short_page; do
        export "INDEX_${short_page//./_}=${long_page:0:1}"
    done 4<<< "$(printf "%s\n" "${_PAGES[@]}")" 5<<< "$(printf "%s\n" "${PAGES[@]}")"
    # reverse to sort it by num
    mapfile -t PAGES <<< "$(_reverse "${PAGES[@]}")"
    mapfile -t PAGES <<< "$(_remove_array_duplicates "${PAGES[@]}")"

    export SLUG PAGES REFERER="manga4life.com"
}

_download_chapter_manga4life() {
    declare index="INDEX_${page//./_}"
    curl -s -L --compressed "https://manga4life.com/read-online/${SLUG}-chapter-${page}-index-${!index}.html" -w "\n%{http_code}\n"
}

_count_images_manga4life() {
    TOTAL_IMAGES="$(: "$(for page in "${PAGES[@]}"; do
        {
            _tmp="$(grep -E 'vm.CurChapter = |vm.CurPathName = ' "${page}/${page}"_chapter)"
            server="$(: "${_tmp##*vm.CurPathName = \"}" && printf "%s\n" "${_%%\";*}")"
            total_images="$(: "${_tmp##*\"Page\"\:\"}" && printf "%s\n" "${_%%\"*}")"
            dir="$(: "${_tmp##*\"Directory\"\:\"}" && printf "%s\n" "${_%%\"*}")"
            # create chapter number for url
            _tmp="000${page}"
            if [[ ${page} = *"."* ]]; then
                chap="${_tmp: -6}"
            else
                chap="${_tmp: -4}"
            fi
            for ((i = 1; i <= total_images; i++)); do
                # create image number for url
                : "00${i}" && image="${_: -3}"
                printf "%s\n" "https://${server}/manga/${SLUG}${dir:+/${dir}}/${chap}-${image}.png"
            done >| "${page}/${page}"_images
            printf "%s\n" "${total_images}"
        } &
    done)" && printf "%s\n" "$((${_//$'\n'/ + }))")"
    export TOTAL_IMAGES
}
