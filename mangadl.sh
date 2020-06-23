#!/usr/bin/env bash
# Search and download mangas from various sources
# See utils folders for available sources.
# shellcheck disable=SC2016

_usage() {
    printf "%b" "
The script can be used to search and download mangas from various sources.\n
Usage: ${0##*/} manga_name/manga_url [options.. ]\n
Options:\n
  -d | --directory - Custom workspace folder.\n
  -s | --source 'name of source' - Source where the input will be searched.\n\nAvailable sources: ${ALL_SOURCES[*]}\n
      To change default source, use mangadl -s default=sourcename\n
  -n | --num 'no of searches' - No. of searches to show, default is 10.\n
      To change default no of searches, use mangadl -n default='no of searches'\n
  -p | --parallel 'no of jobs'  - No. of parallel jobs to use.\n
  -r | --range - Custom range, will be asked later in script. Also supports multiple ranges.\n
  -c | --convert 'quality between 1 to 100' - Change quality of images by convert ( imagemagick ) .\n
  -z | --zip - Create zip of downloaded images.\n
  --upload - Upload created zip on pixeldrain.com.\n
  --skip-internet-check - Like the flag says.\n
  --info - Show detailed info, only if script is installed system wide.\n
  -u | --update - Update the installed script in your system.\n
  --uninstall - Uninstall script, remove related files.\n
  -D | --debug - Display script command trace, use before all the flags to see maximum script trace.\n
  -h | --help - Display usage instructions.\n"
    exit
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit
}

###################################################
# Install/Update/uninstall the script.
# Arguments: 1
#   ${1} = uninstall or update
# Result: On
#   ${1} = nothing - Update the script if installed, otherwise install.
#   ${1} = uninstall - uninstall the script
###################################################
_update() {
    declare job="${1:-update}"
    { [[ ${job} =~ uninstall ]] && job_string="--uninstall"; } || :
    _print_center "justify" "Fetching ${job} script.." "-"
    # shellcheck source=/dev/null
    if [[ -f "${HOME}/.mangadl-bash/mangadl-bash.info" ]]; then
        source "${HOME}/.mangadl-bash/mangadl-bash.info"
    fi
    declare repo="${REPO:-Akianonymus/mangadl-bash}" type_value="${TYPE_VALUE:-master}"
    if script="$(curl --compressed -Ls "https://raw.githubusercontent.com/${repo}/${type_value}/install.sh")"; then
        _clear_line 1
        bash <(printf "%s\n" "${script}") ${job_string:-} --skip-internet-check
    else
        _print_center "justify" "Error: Cannot download ${job} script." "="
        exit 1
    fi
    exit "${?}"
}

###################################################
# Print the contents of info file if scipt is installed system wide.
# Path is "${HOME}/.mangadl-bash/mangadl-bash.info"
# Arguments: None
# Result: read description
###################################################
_version_info() {
    if [[ -f ${INFO_FILE} ]]; then
        printf "%s\n" "$(< "${INFO_FILE}")"
    else
        _print_center "justify" "mangadl-bash is not installed system wide." "="
    fi
    exit 0
}

###################################################
# Process all arguments given to the script
# Arguments: Many
#   ${@} = Flags with arguments
# Result: On
#   Success - Set all the variables
#   Error   - Print error message and exit
###################################################
_setup_arguments() {
    unset ALL_SOURCES DEBUG FOLDER SOURCE NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD MAX_BACKGROUD_JOBS NUM_OF_SEARCH
    unset ASK_RANGE CONVERT_QUALITY CONVERT CONVERT_DIR CREATE_ZIP UPLOAD_ZIP SKIP_INTERNET_CHECK INPUT_ARRAY

    INFO_FILE="${HOME}/.mangadl-bash/mangadl-bash.info"
    if [[ -r ${INFO_FILE} ]]; then
        # shellcheck source=/dev/null
        source "${INFO_FILE}" &> /dev/null || :
    fi

    _check_longoptions() {
        { [[ -z ${2} ]] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' \
                "${0##*/}" "${1}" "${0##*/}" && exit 1; } || :
    }

    for _source in "${UTILS_FOLDER}"/*scraper.sh; do
        ALL_SOURCES+=("$(_basename "${_source/-scraper.sh/}")")
    done

    url_regex='(http|https)://[a-zA-Z0-9./?=_%:-]*'
    source_regex='(http|https)://.*('$(printf "%s|" "${ALL_SOURCES[@]}")examplemanga')[a-zA-Z0-9./?=_%:-]'

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                _usage
                ;;
            -D | --debug)
                DEBUG="true" && export DEBUG
                _check_debug
                ;;
            -u | --update)
                _check_debug && _update
                ;;
            --uninstall)
                _check_debug && _update uninstall
                ;;
            --info)
                _version_info
                ;;
            -d | --directory)
                _check_longoptions "${1}" "${2}"
                FOLDER="${2}" && shift
                ;;
            -s | --source)
                _check_longoptions "${1}" "${2}"
                _SOURCE="${2/default=/}"
                { [[ ${2} = default* ]] && UPDATE_DEFAULT_SOURCE="_update_config"; } || :
                for _source in "${ALL_SOURCES[@]}"; do
                    if [[ "${_source}"-scraper.sh = "${_SOURCE}"-scraper.sh ]]; then
                        SOURCE="${_SOURCE}" && shift
                        break
                    fi
                done
                if [[ -z ${SOURCE} ]]; then
                    printf "%s\n" "Error: Given source ( ${2} ) is not supported."
                    exit 1
                fi
                ;;
            -n | --num)
                _check_longoptions "${1}" "${2}"
                _NUM_OF_SEARCH="${2/default=/}"
                { [[ ${2} = default* ]] && UPDATE_DEFAULT_NUM_OF_SEARCH="_update_config"; } || :
                case "${_NUM_OF_SEARCH}" in
                    all | *[0-9]*)
                        NUM_OF_SEARCH="${2}"
                        ;;
                    *[!0-9]*)
                        printf "\nError: -n/--num accept arguments as postive integets.\n"
                        exit 1
                        ;;
                esac
                shift
                ;;
            -p | --parallel)
                _check_longoptions "${1}" "${2}"
                NO_OF_PARALLEL_JOBS="${2}"
                case "${NO_OF_PARALLEL_JOBS}" in
                    '' | *[!0-9]*)
                        printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
                        exit 1
                        ;;
                    *)
                        [[ ${NO_OF_PARALLEL_JOBS} -gt 10 ]] && { NO_OF_PARALLEL_JOBS=10 || NO_OF_PARALLEL_JOBS="${2}"; }
                        ;;
                esac
                PARALLEL_DOWNLOAD="true" && export PARALLEL_DOWNLOAD
                shift
                ;;
            -r | --range)
                ASK_RANGE="true"
                ;;
            -c | --convert)
                _check_longoptions "${1}" "${2}"
                CONVERT_QUALITY="${2}"
                case "${CONVERT_QUALITY}" in
                    '' | *[!0-9]*)
                        printf "\nError: -c/--convert value ranges between 1 to 100.\n"
                        exit 1
                        ;;
                    *)
                        [[ ${CONVERT_QUALITY} -gt 100 ]] && { CONVERT_QUALITY=100 || CONVERT_QUALITY="${2}"; }
                        ;;
                esac
                CONVERT="true" && CONVERT_DIR="converted"
                shift
                ;;
            -z | --zip)
                CREATE_ZIP="true"
                ;;
            -U | --upload)
                UPLOAD_ZIP="true"
                ;;
            --skip-internet-check)
                SKIP_INTERNET_CHECK=":"
                ;;
            '')
                shorthelp
                ;;
            *)
                # Check if user meant it to be a flag
                if [[ ${1} = -* ]]; then
                    printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                else
                    # If no "-" is detected in 1st arg, it adds to input
                    INPUT_ARRAY+=("${1}")
                fi
                ;;
        esac
        shift
    done

    SOURCE="${SOURCE:-mangahub}"
    "${UPDATE_DEFAULT_SOURCE:-:}" SOURCE "${SOURCE}" "${INFO_FILE}"
    NUM_OF_SEARCH="${NUM_OF_SEARCH:-10}"
    "${UPDATE_DEFAULT_NUM_OF_SEARCH:-:}" SOURCE "${SOURCE}" "${INFO_FILE}"
    { [[ ${NUM_OF_SEARCH} = all ]] && unset NUM_OF_SEARCH; } || :
    NO_OF_PARALLEL_JOBS="${NO_OF_PARALLEL_JOBS:-$(nproc)}"
    if [[ -z ${INPUT_ARRAY[*]} ]]; then
        _short_help
    else
        mapfile -t INPUT_ARRAY <<< "$(_remove_array_duplicates "${INPUT_ARRAY[@]}")"
    fi

}

###################################################
# Setup Temporary file name for writing, uses mktemp, current dir as fallback
# Used in parallel folder uploads progress
# Arguments: None
# Result: read description
###################################################
_setup_tempfile() {
    type -p mktemp &> /dev/null && { TMPFILE="$(mktemp -u)" || TMPFILE="${PWD}/$((RANDOM * 2))"; }
    trap 'rm -f "${TMPFILE}"*' EXIT
}

###################################################
# Source functions related to required source type
# Arguments: 1
#   ${1} - source name ( optional )
# Result: read description
###################################################
_source_manga_util() {
    SOURCE="${1:-${SOURCE}}"
    utils_file="${UTILS_FOLDER}/${SOURCE}-scraper.sh"
    if [[ -r ${utils_file} ]]; then
        # shellcheck source=/dev/null
        source "${utils_file}" || { printf "Error: Unable to source file ( %s ) .\n" "${utils_file}" 1>&2 && exit 1; }
    else
        printf "Error: Utils file ( %s ) not found\n" "${utils_file}" 1>&2
        exit 1
    fi
}

###################################################
# Process all the values in "${INPUT_ARRAY[@]}"
# Arguments: None
# Result: Do whatever set by flags
###################################################
_process_arguments() {
    declare input utils_file _exit

    _source_manga_util

    CURRENT_DIR="${PWD}"

    { [[ -n ${FOLDER} ]] && mkdir -p "${FOLDER}" && { cd "${FOLDER:-.}" || exit 1; }; } || :

    for input in "${INPUT_ARRAY[@]}"; do
        if [[ ${input} =~ ${url_regex} ]]; then
            if [[ ${input} =~ ${source_regex} ]]; then
                source_of_url="$(_regex "${input}" ''"$(printf "%s|" "${ALL_SOURCES[@]}")examplemanga"'' 0)"
                _source_manga_util "${source_of_url}"
                _print_center "justify" "Fetching manga details.." "-"
                _fetch_manga_details "${input}" fetch_name || { _clear_line 1 && _print_center "justify" "Error: Invalid manga url." "=" && _newline "\n" && continue; }
                _clear_line 1
                _print_center "justify" "${NAME}" "="
            else
                _print_center "justify" "URL not supported." "="
                _newline "\n" && continue
            fi
        else
            unset _exit
            _print_center "justify" "${input}" "="
            _print_center "justify" "Searching in" " ${SOURCE}" "-"

            _search_manga "${input}" "${NUM_OF_SEARCH}" || _exit="1"

            _clear_line 1
            _print_center "justify" "Source" ": ${SOURCE}" "="
            _print_center "justify" "${TOTAL_SEARCHES:-0} results found" "="
            { [[ -n ${_exit} ]] && _newline "\n" && continue; } || :
            printf "\n%s\n" "${OPTION_NAMES[@]}" && _newline "\n"

            read -r -p "Choose: " option
            option="${option// /}"

            if [[ -n ${option} ]]; then
                if [[ ${option} -lt 0 || ${option} -gt ${#OPTION_NAMES[@]} ]]; then
                    _print_center "justify" "Invalid option." "="
                    _newline "\n" && continue
                fi
            else
                _print_center "justify" "No option given." "="
                _newline "\n" && continue
            fi

            _set_manga_variables "${option}"

            _print_center "justify" "${NAME}" "="

            _print_center "justify" "Fetching manga details.." "-"
            _fetch_manga_details "${URL}"
            _clear_line 1
        fi

        mkdir -p "${NAME}"
        FULL_PATH_NAME="$(_full_path "${NAME}")"
        cd "${NAME}" || exit 1

        FINAL_RANGE="${PAGES[0]}"-"${PAGES[$((${#PAGES[@]} - 1))]}"

        if [[ -n ${ASK_RANGE} ]]; then
            _print_center "justify" "Input chapters" "-"
            printf "%b " "${PAGES[@]}" && _newline "\n\n"

            # shellcheck disable=SC2001
            mapfile -t PAGES <<< "$(printf "%s\n" "${PAGES[@]}" | sed "s/\(^\|$\)/_-_-_/g")"
            printf "%s\n> " "Give range, e.g: 1 2-10 69"
            read -r -a RANGE
            { [[ -z ${RANGE[*]} ]] && _print_center "justify" "Error: Empty input." "=" && exit 1; } || :
            for var in "${RANGE[@]}"; do
                regex=""
                if [[ "${var}" =~ ^([0-9]+)-([0-9]+)+$ ]]; then
                    initial="${var/-*/}"
                    final="${var/*-/}"

                    if [[ ${initial} -gt ${final} ]]; then
                        initial="${var/*-/}"
                        final="${var/-*/}"
                    elif [[ ${initial} -eq ${final} ]]; then
                        regex="_-_-_${initial}_-_-_"
                    fi

                    regex="${regex:-_-_-_${initial}_-_-_.*_-_-_${final}_-_-_}"

                    if [[ ${PAGES[*]} =~ ${regex} ]]; then
                        TEMP_PAGES+="$(: "${BASH_REMATCH[@]//_-_-_ _-_-_/$'\n'}" && printf "%s\n" "${_//_-_-_/}")"
                    else
                        _print_center "justify" "Invalid Range" " ( non-existent range )." "="
                        exit 1
                    fi
                elif [[ "${var}" =~ ^([0-9]+)+$ ]]; then
                    regex="_-_-_${var}_-_-_"
                    if [[ ${PAGES[*]} =~ ${regex} ]]; then
                        TEMP_PAGES+="$(: "${BASH_REMATCH[@]//_-_-_ _-_-_/$'\n'}" && printf "%s\n" "${_//_-_-_/}")
"
                    else
                        _print_center "justify" "Invalid chapter" " ( non-existent chapter )." "="
                        exit 1
                    fi
                else
                    _print_center "justify" "Invalid Range" " ( wrong format )." "="
                    exit 1
                fi
            done
            mapfile -t PAGES <<< "${TEMP_PAGES}"
            mapfile -t PAGES <<< "$(_remove_array_duplicates "${PAGES[@]}")"
            FINAL_RANGE="$(: "$(_remove_array_duplicates "${RANGE[@]}")" && printf "%s\n" "${_//$'\n'/,}")"
        fi

        TOTAL_CHAPTERS="${#PAGES[@]}"

        _print_center "justify" "${TOTAL_CHAPTERS} chapter(s)" "="

        _print_center "justify" "Fetching" " chapter details.." "-"

        mkdir -p "${PAGES[@]}"

        _fetch_manga_chapters
        _clear_line 1

        _print_center "justify" "Counting Images.." "-"
        _count_images
        for _ in {1..2}; do _clear_line 1; done
        _print_center "justify" "${TOTAL_CHAPTERS} chapters" " | ${TOTAL_IMAGES} images" "="

        _print_center "justify" "Downloading" " images.." "-" && _newline "\n"
        _download_images
        _clear_line 1
        TOTAL_IMAGES="$(_count <<< "${IMAGES}")"
        _print_center "justify" "${TOTAL_IMAGES}" " images downloaded." "="
        _print_center "justify" "${TOTAL_IMAGES_SIZE}" "=" && _newline "\n"

        if [[ -n ${CONVERT} ]]; then
            _print_center "justify" "Converting images.." "-"
            _print_center "justify" "Quality: ${CONVERT_QUALITY}%" "=" && _newline "\n"
            export CONVERT_QUALITY CONVERT_DIR
            { mkdir -p "${CONVERT_DIR}" && cd "${CONVERT_DIR}" && mkdir -p "${PAGES[@]}" && cd - &> /dev/null; } || exit 1
            export -f _dirname _basename _name
            printf "%s\n" "${IMAGES}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS:-$(($(nproc) * 2))}" -i bash -c '
                image="{}"
                target_image="${CONVERT_DIR}"/"$(_dirname "${image/.\//}")"/"$(_basename "$(_name "${image%.*}")")".jpg
                if convert "${image}" -quality "${target_image}" &> /dev/null; then
                    printf "1\n"
                else
                    printf "2\n" 1>&2
                    cp "${image}" "${target_image}"
                fi
                ' 1> "${TMPFILE}".success 2> "${TMPFILE}".error &

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
                else
                    break
                fi
                TOTAL_STATUS="$((SUCCESS_STATUS + ERROR_STATUS))"
            done
            rm -f "${TMPFILE}".success "${TMPFILE}".error
            for _ in {1..3}; do _clear_line 1; done
            _print_center "justify" "Converted ${TOTAL_IMAGES}" " images ( ${CONVERT_QUALITY}% )" "="
        fi

        if [[ -n ${CREATE_ZIP} ]]; then
            _print_center "justify" "Creating zip.." "=" && _newline "\n"

            cd "${CONVERT_DIR:-.}" || exit

            ZIPNAME="${NAME}${FINAL_RANGE+_${FINAL_RANGE}}${CONVERT_DIR+_${CONVERT_DIR}_${CONVERT_QUALITY}%}".zip
            # shellcheck disable=SC2086
            zip -x "*chapter" "*images" -u -q -r9 -lf "${TMPFILE}".log -li -la "${FULL_PATH_NAME}"/"${ZIPNAME}" "${PAGES[@]}" &

            until [[ -f "${TMPFILE}".log ]]; do
                _bash_sleep 0.5
            done

            TOTAL_ZIP_STATUS="$((TOTAL_IMAGES + TOTAL_CHAPTERS))"
            until [[ -z $(jobs -p) ]]; do
                STATUS=$(grep 'up to date\|updating\|adding' "${TMPFILE}".log -c)
                _bash_sleep 0.5
                if [[ ${STATUS} != "${OLD_STATUS}" ]]; then
                    _clear_line 1
                    _print_center "justify" "${STATUS}" " / ${TOTAL_ZIP_STATUS}" "="
                fi
                OLD_STATUS="${STATUS}"
            done
            for _ in {1..2}; do _clear_line 1; done
            rm -f "${TMPFILE}".log

            ZIP_SIZE="$(_bytes_to_human "$(wc -c < "${FULL_PATH_NAME}/${ZIPNAME}")")"
            _print_center "justify" "${ZIPNAME}" "="
            _newline "\n" && _print_center "normal" "Path: \"${FULL_PATH_NAME/${CURRENT_DIR}\//}/${ZIPNAME}\" " " " && _newline "\n"
            _print_center "justify" "${ZIP_SIZE}" "=" && _newline "\n"

            if [[ -n ${UPLOAD_ZIP} ]]; then
                _print_center "justify" "Uploading zip.." "-"
                DOWNLOAD_URL="$(upload "${ZIPNAME}")"
                for _ in {1..2}; do _clear_line 1; done
                _print_center "justify" "ZipLink" "="
                _print_center "normal" "$(printf "%b\n" "\xe2\x86\x93 \xe2\x86\x93 \xe2\x86\x93")" " "
                _print_center "normal" "${DOWNLOAD_URL}" " " && _newline "\n"
            fi
        fi
    done
}

main() {
    declare utils_file
    [[ $# = 0 ]] && _short_help

    trap 'exit "${?}"' INT TERM && trap 'kill 0' EXIT

    UTILS_FOLDER="${UTILS_FOLDER:-./utils}"
    utils_file="${UTILS_FOLDER}/utils.sh"
    if [[ -r ${utils_file} ]]; then
        # shellcheck source=/dev/null
        source "${utils_file}" || { printf "Error: Unable to source file ( %s ) .\n" "${utils_file}" 1>&2 && exit 1; }
    else
        printf "Error: Utils file ( %s ) not found\n" "${utils_file}" 1>&2
        exit 1
    fi

    _check_bash_version
    _setup_arguments "${@}"
    _setup_tempfile
    _check_debug && "${SKIP_INTERNET_CHECK:-_check_internet}"

    START="$(printf "%(%s)T\\n" "-1")"
    _process_arguments
    END="$(printf "%(%s)T\\n" "-1")"
    DIFF="$((END - START))"

    _print_center "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds. " "="
}

main "${@}"
