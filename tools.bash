#!/usr/bin/env bash
# Functions related to making new scrapers and other misc stuff
# shellcheck disable=SC2016

_usage() {
    printf "%b" "Lol, something else.\n"
    exit 0
}

main() {
    [[ $# = 0 ]] && _usage
    NAME="${1:?1 - Provide name.}"

    read -rd '' SCRIPT << 'EOF'
#!/usr/bin/env bash
# Functions related to dummymanga
# shellcheck disable=SC2016

_search_manga_dummymanga() {
    declare input="${1}" num_of_search="${2}"
    export TOTAL_SEARCHES OPTION_NAMES NAMES SLUGS
}

_set_manga_variables_dummymanga() {
    declare option="${1}"

    SLUG="${SLUGS[$((option - 1))]}"
    NAME="${NAMES[$((option - 1))]}"

    export SLUG NAME
}

_fetch_manga_details_dummymanga() {
    declare url="${1:-${URL}}" fetch_name="${2:-}"
    export SLUG PAGES REFERER="dummymanga"
}

_download_chapter_dummymanga() {
    curl -s -L --compressed "${rest_of_the_url}${page}" -w "\n%{http_code}\n"
}

_count_images_dummymanga() {
    TOTAL_IMAGES="$(: "$(for page in "${PAGES[@]}"; do
        {
            printf "%s\n" "${images}" >| "${page}/${page}"_images
            _count < "${page}/${page}"_images
        } &
    done)" && printf "%s\n" "$((${_//$'\n'/ + }))")"
    export TOTAL_IMAGES
}
EOF

    printf "%s\n" "${SCRIPT//dummymanga/${NAME}}" >| utils/"${NAME}"-scraper.bash
}

main "${@}"
