#!/usr/bin/env bash
# Functions that will used in core script

###################################################
# Alternative to basename command
# Globals: None
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
# Alternative to sleep command
# Globals: None
# Arguments: 1
#   ${1} = Positive integer ( amount of time in seconds to sleep )
# Result: Sleeps for the specified amount of time.
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#use-read-as-an-alternative-to-the-sleep-command
###################################################
_bash_sleep() {
    read -rt "${1}" <> <(:) || :
}

###################################################
# Convert bytes to human readable form
# Globals: None
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
# Globals: 1 Variable
#   BASH_VERSINFO
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
        set -x
        _print_center() { { [[ $# = 3 ]] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
        _clear_line() { :; } && _newline() { :; }
    else
        set +x
        if [[ -z ${QUIET} ]]; then
            if _is_terminal; then
                # This refreshes the interactive shell so we can use the ${COLUMNS} variable in the _print_center function.
                shopt -s checkwinsize && (: && :)
                if [[ ${COLUMNS} -lt 40 ]]; then
                    _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                else
                    trap 'shopt -s checkwinsize; (:;:)' SIGWINCH
                fi
            else
                _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                _clear_line() { :; }
            fi
            _newline() { printf "%b" "${1}"; }
        else
            _print_center() { :; } && _clear_line() { :; } && _newline() { :; }
        fi
    fi
}

###################################################
# Check internet connection.
# Probably the fastest way, takes about 1 - 2 KB of data, don't check for more than 10 secs.
# Globals: 2 functions
#   _print_center, _clear_line
# Arguments: None
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_internet() {
    _print_center "justify" "Checking Internet Connection.." "-"
    if ! _timeout 10 curl -Is google.com; then
        _clear_line 1
        printf "Error: Internet connection not available.\n"
        exit 1
    fi
    _clear_line 1
}

###################################################
# Move cursor to nth no. of line and clear it to the begining.
# Globals: None
# Arguments: 1
#   ${1} = Positive integer ( line number )
# Result: Read description
###################################################
_clear_line() {
    printf "\033[%sA\033[2K" "${1}"
}

###################################################
# Alternative to wc -l command
# Globals: None
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
# Globals: None
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
# Globals: None
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
# Print full path of a file/folder
# Globals: 1 variable
#   PWD
# Arguments: 1
#   ${1} = name of file/folder
# Result: print full path
###################################################
_full_path() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare input="${1}"
    if [[ -f ${input} ]]; then
        printf "%s/%s\n" "$(cd "$(_dirname "${input}")" &> /dev/null && pwd)" "${input##*/}"
    elif [[ -d ${input} ]]; then
        printf "%s\n" "$(cd "${input}" &> /dev/null && pwd)"
    fi
}

###################################################
# Fetch latest commit sha of release or branch
# Uses github rest api v3
# Globals: None
# Arguments: 3
#   ${1} = "branch" or "release"
#   ${2} = branch name or release name
#   ${3} = repo name e.g labbots/google-drive-upload
# Result: print fetched sha
###################################################
_get_latest_sha() {
    declare LATEST_SHA
    case "${1:-${TYPE}}" in
        branch)
            LATEST_SHA="$(curl --compressed -s https://api.github.com/repos/"${3:-${REPO}}"/commits/"${2:-${TYPE_VALUE}}" | _json_value sha 1 1)"
            ;;
        release)
            LATEST_SHA="$(curl --compressed -s https://api.github.com/repos/"${3:-${REPO}}"/releases/"${2:-${TYPE_VALUE}}" | _json_value tag_name 1 1)"
            ;;
    esac
    printf "%s\n" "${LATEST_SHA}"
}

###################################################
# Alternative to head -n command
# Globals: None
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
# Check if script running in a terminal
# Globals: 1 variable
#   TERM
# Arguments: None
# Result: return 1 or 0
###################################################
_is_terminal() {
    [[ -t 1 || -z ${TERM} ]] && return 0 || return 1
}

###################################################
# Method to extract specified field data from json
# Globals: None
# Arguments: 2
#   ${1} - value of field to fetch from json
#   ${2} - Optional, no of lines to parse
#   ${3} - Optional, nth number of value from extracted values, default it 1.
# Input: file | here string | pipe
#   _json_value "Arguments" < file
#   _json_value "Arguments <<< "${varibale}"
#   echo something | _json_value "Arguments"
# Result: print extracted value
###################################################
_json_value() {
    declare LC_ALL=C num
    { [[ ${2} =~ ^([0-9]+)+$ ]] && no_of_lines="${2}"; } || :
    { [[ ${3} =~ ^([0-9]+)+$ ]] && num="${3}"; } || { [[ ${3} != all ]] && num=1; }
    grep -o "\"${1}\"\:.*" ${no_of_lines+-m ${no_of_lines}} | sed -e "s/.*\"""${1}""\"://" -e 's/[",]*$//' -e 's/["]*$//' -e 's/[,]*$//' -e "s/^ //" -e 's/^"//' -n -e "${num}"p
}

###################################################
# Print name of input
# Globals: None
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
# Globals: 1 variable
#   COLUMNS
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
        normal)
            declare out="${2}" && symbol="${3}"
            ;;
        justify)
            if [[ $# = 3 ]]; then
                declare input1="${2}" symbol="${3}" TO_PRINT out
                TO_PRINT="$((TERM_COLS - 5))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && out="[ ${input1:0:TO_PRINT}..]"; } || { out="[ ${input1} ]"; }
            else
                declare input1="${2}" input2="${3}" symbol="${4}" TO_PRINT temp out
                TO_PRINT="$((TERM_COLS * 40 / 100))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && temp+=" ${input1:0:TO_PRINT}.."; } || { temp+=" ${input1}"; }
                TO_PRINT="$((TERM_COLS * 55 / 100))"
                { [[ ${#input2} -gt ${TO_PRINT} ]] && temp+="${input2:0:TO_PRINT}.. "; } || { temp+="${input2} "; }
                out="[${temp}]"
            fi
            ;;
        *) return 1 ;;
    esac

    declare -i str_len=${#out}
    [[ $str_len -ge $(((TERM_COLS - 1))) ]] && {
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
# Match the two give strings and print the rematch
# Globals: None
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
# Globals: None
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
# Globals: None
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
# Globals: None
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
#   https://stackoverflow.com/a/11056286
###################################################
_timeout() {
    declare -i sleep="${1}" && shift
    declare -i pid watcher
    {
        { "${@}"; } &
        pid="${!}"
        { read -r -t "${sleep:-10}" && kill -HUP "${pid}"; } &
        watcher="${!}"
        if wait "${pid}" 2> /dev/null; then
            kill -9 "${watcher}"
            return 0
        else
            return 1
        fi
    } &> /dev/null
}

###################################################
# Config updater
# Incase of old value, update, for new value add.
# Globals: 1 function
#   _remove_array_duplicates
# Arguments: 3
#   ${1} = value name
#   ${2} = value
#   ${3} = config path
# Result: read description
###################################################
_update_config() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare VALUE_NAME="${1}" VALUE="${2}" CONFIG_PATH="${3}" FINAL=()
    printf "" >> "${CONFIG_PATH}" # If config file doesn't exist.
    mapfile -t VALUES < "${CONFIG_PATH}" && VALUES+=("${VALUE_NAME}=\"${VALUE}\"")
    for i in "${VALUES[@]}"; do
        [[ ${i} =~ ${VALUE_NAME}\= ]] && FINAL+=("${VALUE_NAME}=\"${VALUE}\"") || FINAL+=("${i}")
    done
    _remove_array_duplicates "${FINAL[@]}" >| "${CONFIG_PATH}"
}

###################################################
# Upload a file to pixeldrain.com
# Globals: None
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
