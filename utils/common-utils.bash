#!/usr/bin/env bash
# Functions that will used in core script

###################################################
# Alternative to basename command
# Arguments: 1
#   ${1} = anything
# Result: Read description.
###################################################
_basename() {
    declare tmp

    tmp=${1%"${1##*[!/]}"}
    tmp=${tmp##*/}
    tmp=${tmp%"${2/"$tmp"/}"}

    printf '%s\n' "${tmp:-/}"
}

###################################################
# Convert bytes to human readable form
# Required Arguments: 1
#   ${1} = Positive integer ( bytes )
# Result: Print human readable form.
# Reference:
#   https://unix.stackexchange.com/a/259254
###################################################
_bytes_to_human() {
    declare b=${1:-0} d='' s=0 S=(Bytes {K,M,G,T,P,E,Y,Z}B)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024)) && ((s++))
    done
    printf "%s\n" "${b}${d} ${S[${s}]}"
}

###################################################
# Check for bash version >= 4.x
# Required Arguments: None
# Result: If
#   SUCEESS: Status 0
#   ERROR: print message and exit 1
###################################################
_check_bash_version() {
    { ! [[ ${BASH_VERSINFO:-0} -ge 4 ]] && printf "Bash version lower than 4.x not supported.\n" && exit 1; } || :
}

###################################################
# Check if debug is enabled and enable command trace
# Globals: 2 variables, 1 function
#   Varibles - DEBUG, QUIET
#   Function - _is_terminal
# Arguments: None
# Result: If DEBUG
#   Present - Enable command trace and change print functions to avoid spamming.
#   Absent  - Disable command trace
#             Check QUIET, then check terminal size and enable print functions accordingly.
###################################################
_check_debug() {
    _print_center_quiet() { { [[ $# = 3 ]] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
    if [[ -n ${DEBUG} ]]; then
        set -x && PS4='-> '
        _print_center() { { [[ $# = 3 ]] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
        _clear_line() { :; } && _newline() { :; }
    else
        if [[ -z ${QUIET} ]]; then
            if _support_ansi_escapes; then
                # This refreshes the interactive shell so we can use the ${COLUMNS} variable in the _print_center function.
                shopt -s checkwinsize && (: && :)
                if [[ ${COLUMNS} -lt 45 ]]; then
                    _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                else
                    trap 'shopt -s checkwinsize; (:;:)' SIGWINCH
                fi
                CURL_PROGRESS="-#" EXTRA_LOG="_print_center" CURL_PROGRESS_EXTRA="-#"
                export CURL_PROGRESS EXTRA_LOG CURL_PROGRESS_EXTRA
            else
                _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                _clear_line() { :; }
            fi
            _newline() { printf "%b" "${1}"; }
        else
            _print_center() { :; } && _clear_line() { :; } && _newline() { :; }
        fi
        set +x
    fi
}

###################################################
# Check internet connection.
# Probably the fastest way, takes about 1 - 2 KB of data, don't check for more than 10 secs.
# Arguments: None
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_internet() {
    "${EXTRA_LOG:-:}" "justify" "Checking Internet Connection.." "-"
    if ! _timeout 10 curl -Is google.com; then
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Internet connection" " not available." "="
        exit 1
    fi
    _clear_line 1
}

###################################################
# check the given ranges in ${PAGES[@]}
# add proper entry to RANGE array from the PAGES array
###################################################
_check_and_create_range() {
    for range in "${@}"; do
        unset start end _start _end
        if [[ "${range}" =~ ^([0-9]+)-([0-9]+|last)+$ ]]; then
            _start="${range/-*/}" _end="${range/*-/}"
            # check if range has last
            [[ ${_end} = last ]] && _end="${#PAGES[@]}"
            # reciprocate the ranges if start < end
            if [[ ${_start} -gt ${_end} ]]; then
                _start="${_end}"
                _end="${range/-*/}"
                # if equal, just add a single range to RANGE
            elif [[ ${_start} -eq ${_end} ]]; then
                [[ ${_start} -lt 1 ]] && _start=1
                [[ ${_start} -gt ${#PAGES[@]} ]] && _start="${#PAGES[@]}"
                start="${PAGES[$((_start - 1))]}"
                [[ -z ${start} ]] && printf "%s\n" "Error: invalid chapter ( ${start} )." && return 1
                RANGE+=("${start}")
                continue
            fi
            # check ranges are within possible ranges
            [[ ${_start} -lt 1 ]] && _start=1
            # in case of end range exceeding total number of chapters, set last page to last possible chapter
            [[ ${_end} -gt ${#PAGES[@]} ]] && _end="${#PAGES[@]}"
            # handle a edgecase when only 1 chapters are available
            [[ ${_start} = ${_end} ]] && unset _end

            start="${PAGES[$((_start - 1))]}"
            [[ -z ${start} ]] && printf "%s\n" "Error: invalid chapter ( ${start} )." && return 1
            [[ -n ${_end} ]] && end="${PAGES[$((_end - 1))]}"

            # add end range only if available
            RANGE+=("${start}${end:+-${end}}")
        elif [[ "${range}" =~ ^([0-9]+|last)+$ ]]; then
            { [[ ${range} = last ]] && _start="${#PAGES[@]}"; } || {
                [[ ${range} -lt 1 ]] && _start=1
                [[ ${range} -gt ${#PAGES[@]} ]] && _start="${#PAGES[@]}"
            }

            _start="${_start:-${range}}"

            start="${PAGES[$((_start - 1))]}"
            [[ -z ${start} ]] && printf "%s\n" "Error: invalid chapter ( ${start} )." && return 1
            RANGE+=("${start}")
        else
            printf "%s\n" "Error: Invalid range ( ${range} )." && return 1
        fi
    done
}

###################################################
# Move cursor to nth no. of line and clear it to the begining.
# Arguments: 1
#   ${1} = Positive integer ( line number )
# Result: Read description
###################################################
_clear_line() {
    printf "\033[%sA\033[2K" "${1}"
}

###################################################
# Alternative to wc -l command
# Arguments: 1  or pipe
#   ${1} = file, _count < file
#          variable, _count <<< variable
#   pipe = echo something | _count
# Result: Read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#get-the-number-of-lines-in-a-file
###################################################
_count() {
    mapfile -tn 0 lines
    printf '%s\n' "${#lines[@]}"
}

###################################################
# Alternative to dirname command
# Arguments: 1
#   ${1} = path of file or folder
# Result: read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#get-the-directory-name-of-a-file-path
###################################################
_dirname() {
    declare tmp=${1:-.}

    [[ ${tmp} != *[!/]* ]] && { printf '/\n' && return; }
    tmp="${tmp%%"${tmp##*[!/]}"}"

    [[ ${tmp} != */* ]] && { printf '.\n' && return; }
    tmp=${tmp%/*} && tmp="${tmp%%"${tmp##*[!/]}"}"

    printf '%s\n' "${tmp:-/}"
}

###################################################
# Convert given time in seconds to readable form
# 110 to 1 minute(s) and 50 seconds
# Arguments: 1
#   ${1} = Positive Integer ( time in seconds )
# Result: read description
# Reference:
#   https://stackoverflow.com/a/32164707
###################################################
_display_time() {
    declare T="${1}"
    declare DAY="$((T / 60 / 60 / 24))" HR="$((T / 60 / 60 % 24))" MIN="$((T / 60 % 60))" SEC="$((T % 60))"
    [[ ${DAY} -gt 0 ]] && printf '%d days ' "${DAY}"
    [[ ${HR} -gt 0 ]] && printf '%d hrs ' "${HR}"
    [[ ${MIN} -gt 0 ]] && printf '%d minute(s) ' "${MIN}"
    [[ ${DAY} -gt 0 || ${HR} -gt 0 || ${MIN} -gt 0 ]] && printf 'and '
    printf '%d seconds\n' "${SEC}"
}

###################################################
# Fetch latest commit sha of release or branch
# Do not use github rest api because rate limit error occurs
# Arguments: 3
#   ${1} = "branch" or "release"
#   ${2} = branch name or release name
#   ${3} = repo name e.g Akianonymus/mangadl-bash
# Result: print fetched sha
###################################################
_get_latest_sha() {
    declare LATEST_SHA
    case "${1:-${TYPE}}" in
        branch)
            LATEST_SHA="$(
                : "$(curl --compressed -s https://github.com/"${3:-${REPO}}"/commits/"${2:-${TYPE_VALUE}}".atom -r 0-2000)"
                : "$(printf "%s\n" "${_}" | grep -o "Commit\\/.*<" -m1 || :)" && : "${_##*\/}" && printf "%s\n" "${_%%<*}"
            )"
            ;;
        release)
            LATEST_SHA="$(
                : "$(curl -L --compressed -s https://github.com/"${3:-${REPO}}"/releases/"${2:-${TYPE_VALUE}}")"
                : "$(printf "%s\n" "${_}" | grep "=\"/""${3:-${REPO}}""/commit" -m1 || :)" && : "${_##*commit\/}" && printf "%s\n" "${_%%\"*}"
            )"
            ;;
    esac
    printf "%b" "${LATEST_SHA:+${LATEST_SHA}\n}"
}

###################################################
# Alternative to head -n command
# Arguments: 1  or pipe
#   ${1} = file, _head 1 < file
#          variable, _head 1 <<< variable
#   pipe = echo something | _head 1
# Result: Read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible/blob/master/README.md#get-the-first-n-lines-of-a-file
###################################################
_head() {
    mapfile -tn "$1" line
    printf '%s\n' "${line[@]}"
}

###################################################
# Method to extract specified field data from json
# Globals: None
# Arguments: 2
#   ${1} - value of field to fetch from json
#   ${2} - Optional, no of lines to parse for the given field in 1st arg
#   ${3} - Optional, nth number of value from extracted values, default it 1.
# Input: file | here string | pipe
#   _json_value "Arguments" < file
#   _json_value "Arguments" <<< "${varibale}"
#   echo something | _json_value "Arguments"
# Result: print extracted value
###################################################
_json_value() {
    declare num _tmp no_of_lines
    { [[ ${2} -gt 0 ]] && no_of_lines="${2}"; } || :
    { [[ ${3} -gt 0 ]] && num="${3}"; } || { [[ ${3} != all ]] && num=1; }
    # shellcheck disable=SC2086
    _tmp="$(grep -o "\"${1}\"\:.*" ${no_of_lines:+-m} ${no_of_lines})" || return 1
    printf "%s\n" "${_tmp}" | sed -e "s/.*\"""${1}""\"://" -e 's/[",]*$//' -e 's/["]*$//' -e 's/[,]*$//' -e "s/^ //" -e 's/^"//' -n -e "${num}"p || :
}

###################################################
# Print name of input
# Arguments: 1
#   ${1} = anything
# Result: Read description.
###################################################
_name() {
    printf "%s\n" "${1%.*}"
}

###################################################
# Print a text to center interactively and fill the rest of the line with text specified.
# This function is fine-tuned to this script functionality, so may appear unusual.
# Arguments: 4
#   If ${1} = normal
#      ${2} = text to print
#      ${3} = symbol
#   If ${1} = justify
#      If remaining arguments = 2
#         ${2} = text to print
#         ${3} = symbol
#      If remaining arguments = 3
#         ${2}, ${3} = text to print
#         ${4} = symbol
# Result: read description
# Reference:
#   https://gist.github.com/TrinityCoder/911059c83e5f7a351b785921cf7ecda
###################################################
_print_center() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare -i TERM_COLS="${COLUMNS}"
    declare type="${1}" filler
    case "${type}" in
        normal) declare out="${2}" && symbol="${3}" ;;
        justify)
            if [[ $# = 3 ]]; then
                declare input1="${2}" symbol="${3}" TO_PRINT out
                TO_PRINT="$((TERM_COLS - 5))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && out="[ ${input1:0:TO_PRINT}..]"; } || { out="[ ${input1} ]"; }
            else
                declare input1="${2}" input2="${3}" symbol="${4}" TO_PRINT temp out
                TO_PRINT="$((TERM_COLS * 47 / 100))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && temp+=" ${input1:0:TO_PRINT}.."; } || { temp+=" ${input1}"; }
                TO_PRINT="$((TERM_COLS * 46 / 100))"
                { [[ ${#input2} -gt ${TO_PRINT} ]] && temp+="${input2:0:TO_PRINT}.. "; } || { temp+="${input2} "; }
                out="[${temp}]"
            fi
            ;;
        *) return 1 ;;
    esac

    declare -i str_len=${#out}
    [[ $str_len -ge $((TERM_COLS - 1)) ]] && {
        printf "%s\n" "${out}" && return 0
    }

    declare -i filler_len="$(((TERM_COLS - str_len) / 2))"
    [[ $# -ge 2 ]] && ch="${symbol:0:1}" || ch=" "
    for ((i = 0; i < filler_len; i++)); do
        filler="${filler}${ch}"
    done

    printf "%s%s%s" "${filler}" "${out}" "${filler}"
    [[ $(((TERM_COLS - str_len) % 2)) -ne 0 ]] && printf "%s" "${ch}"
    printf "\n"

    return 0
}

###################################################
# Check if script terminal supports ansi escapes
# Arguments: None
# Result: return 1 or 0
###################################################
_support_ansi_escapes() {
    { [[ -t 2 && -n ${TERM} && ${TERM} =~ (xterm|rxvt|urxvt|linux|vt) ]] && return 0; } || return 1
}

###################################################
# Match the two give strings and print the rematch
# Arguments: 1
#   ${1} = matching string
#   ${2} = matching regex
#   ${3} = no of match to show, optional
# Result: read description
###################################################
_regex() {
    [[ $1 =~ $2 ]] && printf '%s\n' "${BASH_REMATCH[${3:-0}]}"
}

###################################################
# Remove duplicates, maintain the order as original.
# Arguments: 1
#   ${@} = Anything
# Result: read description
# Reference:
#   https://stackoverflow.com/a/37962595
###################################################
_remove_array_duplicates() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare -A Aseen
    Aunique=()
    for i in "$@"; do
        { [[ -z ${i} || ${Aseen[${i}]} ]]; } && continue
        Aunique+=("${i}") && Aseen[${i}]=x
    done
    printf '%s\n' "${Aunique[@]}"
}

###################################################
# Reverse a array
# Arguments: array
#   ${@} = "${array[@]}"
# Result: Read description
# Reference:
#   https://stackoverflow.com/a/39315430
###################################################
_reverse() {
    for ((i = "${#*}"; i > 0; i--)); do
        printf "%s\n" "${!i}"
    done
}

###################################################
# Alternative to tail -n command
# Arguments: 1  or pipe
#   ${1} = file, _tail 1 < file
#          variable, _tail 1 <<< variable
#   pipe = echo something | _tail 1
# Result: Read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible/blob/master/README.md#get-the-last-n-lines-of-a-file
###################################################
_tail() {
    mapfile -tn 0 line
    printf '%s\n' "${line[@]: -$1}"
}

###################################################
# Alternative to timeout command
# Globals: None
# Arguments: 1 and rest
#   ${1} = amount of time to sleep
#   rest = command to execute
# Result: Read description
# Reference:
#   https://stackoverflow.com/a/24416732
###################################################
_timeout() {
    declare timeout="${1:?Error: Specify Timeout}" && shift
    {
        "${@}" &
        child="${!}"
        trap -- "" TERM
        {
            sleep "${timeout}"
            kill -9 "${child}"
        } &
        wait "${child}"
    } 2>| /dev/null 1>&2
}

###################################################
# Config updater
# Incase of old value, update, for new value add.
# Globals: None
# Arguments: 3
#   ${1} = value name
#   ${2} = value
#   ${3} = config path
# Result: read description
###################################################
_update_config() {
    [[ $# -lt 3 ]] && printf "Missing arguments\n" && return 1
    declare value_name="${1}" value="${2}" config_path="${3}"
    ! [ -f "${config_path}" ] && : >| "${config_path}" # If config file doesn't exist.
    chmod u+w "${config_path}"
    printf "%s\n%s\n" "$(grep -v -e "^$" -e "^${value_name}=" "${config_path}" || :)" \
        "${value_name}=\"${value}\"" >| "${config_path}"
    chmod u-w+r "${config_path}"
}

###################################################
# Upload a file to pixeldrain.com
# Arguments: 1
#   ${1} = filename
# Result: print url link
###################################################
_upload() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare input="${1}" json id link
    if ! [[ -f ${input} ]]; then
        printf "Given file ( %s ) doesn't exist\n" "${input}"
        return 1
    fi
    json="$(curl "-#" -F 'file=@'"${input}" "https://pixeldrain.com/api/file")" || return 1
    id="$(: "${json/*id*:\"/}" && printf "%s\n" "${_/\"\}/}")"
    link="https://pixeldrain.com/api/file/${id}?download"
    printf "%s\n" "${link}"
}

###################################################
# Encode the given string to parse properly in network requests
# Arguments: 1
#   ${1} = string
#   ${2} = letter to not encode, optional
# Result: print encoded string
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#percent-encode-a-string
###################################################
_url_encode() {
    declare LC_ALL=C
    for ((i = 0; i < ${#1}; i++)); do
        : "${1:i:1}"
        # shellcheck disable=SC2254
        case "${_}" in
            [a-zA-Z0-9.~_-${2}])
                printf '%s' "${_}"
                ;;
            *)
                printf '%%%02X' "'${_}"
                ;;
        esac
    done
    printf '\n'
}
