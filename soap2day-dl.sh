#!/usr/bin/env bash
#
# Download TV series and Movies from Soap2day using CLI
#
#/ Usage:
#/   ./soap2day-dl.sh [-n <name>] [-p <path>] [-e <num1,num2,num3-num4...>] [-l] [-s] [-x <command>] [-d]
#/
#/ Options:
#/   -n <name>               TV series or Movie name
#/   -p <path>               media path, e.g: /tv_XXXXXXXX.html
#/                           ingored when "-n" is enabled
#/   -e <num1,num3-num4...>  optional, episode number to download
#/                           e.g: episode number "3.2" means Season 3 Episode 2
#/                           multiple episode numbers seperated by ","
#/                           episode range using "-"
#/   -l                      optional, list video link only without downloading
#/   -s                      optional, download subtitle only
#/   -x                      optional, call external download utility
#/   -d                      enable debug mode
#/   -h | --help             display this help message

set -e
set -u

usage() {
    printf "%b\n" "$(grep '^#/' "$0" | cut -c4-)" && exit 1
}

set_var() {
    _CURL="$(command -v curl)" || command_not_found "curl"
    _JQ="$(command -v jq)" || command_not_found "jq"
    _PUP="$(command -v pup)" || command_not_found "pup"
    _FZF="$(command -v fzf)" || command_not_found "fzf"

    _HOST="https://soap2day.ac"
    _SEARCH_URL="$_HOST/search.html?keyword="

    _SCRIPT_PATH=$(dirname "$(realpath "$0")")
    _SEARCH_LIST_FILE="$_SCRIPT_PATH/search.list"
    _SOURCE_FILE=".source.html"
    _EPISODE_LINK_LIST=".episode.link"
    _EPISODE_TITLE_LIST=".episode.title"
    _SUBTITLE_LANG="${SOAP2DAY_SUBTITLE_LANG:-English}"
    _COOKIE="$(get_cookie)"
}

set_args() {
    expr "$*" : ".*--help" > /dev/null && usage
    while getopts ":hlsdn:x:p:e:" opt; do
        case $opt in
            n)
                _INPUT_NAME="${OPTARG// /%20}"
                ;;
            p)
                _MEDIA_PATH="$OPTARG"
                ;;
            e)
                _MEDIA_EPISODE="$OPTARG"
                ;;
            l)
                _LIST_LINK_ONLY=true
                ;;
            s)
                _DOWNLOAD_SUBTITLE_ONLY=true
                ;;
            x)
                _EXTERNAL_COMMAND="$OPTARG"
                ;;
            d)
                _DEBUG_MODE=true
                set -x
                ;;
            h)
                usage
                ;;
            \?)
                print_error "Invalid option: -$OPTARG"
                ;;
        esac
    done
}

print_info() {
    # $1: info message
    printf "%b\n" "\033[32m[INFO]\033[0m $1" >&2
}

print_warn() {
    # $1: warning message
    printf "%b\n" "\033[33m[WARNING]\033[0m $1" >&2
}

print_error() {
    # $1: error message
    printf "%b\n" "\033[31m[ERROR]\033[0m $1" >&2
    exit 1
}

command_not_found() {
    # $1: command name
    print_error "$1 command not found!"
}

sed_remove_space() {
    sed -E '/^[[:space:]]*$/d;s/^[[:space:]]+//;s/[[:space:]]+$//'
}

get_cookie() {
    local sjv="$(( 1 + RANDOM % 1000))" auth
    print_info "Fetching cookie..."
    auth="$("$_CURL" -sS -I "$_HOST/auth" -H "Cookie: sjv=${sjv}" \
        | grep -E "pidq|qt" \
        | awk '{print $2}' \
        | sed -E "s/\r//" \
        | tr '\n' ';')"
    [[ -z "${auth:-}" ]] && print_error "Cannot get cookie. Try again later."
    echo -n "sjv=${sjv};${auth}"
}

get_media_host() {
    # $1: media link
    $_CURL -sS "${_HOST}${1}" \
        -H "Cookie: ${_COOKIE}" \
    | $_PUP "#divU text{}"
}

get_media_id() {
    # $1: URL
    $_CURL -sS "${_HOST}${1}" \
        -H "Cookie: ${_COOKIE}" \
    | $_PUP "#hId attr{value}"
}

get_media_name() {
    # $1: media link
    $_CURL -sS "${_HOST}${1}" \
        -H "Cookie: ${_COOKIE}" \
    | $_PUP ".panel-body h4 text{}" \
    | head -1 \
    | sed_remove_space
}

search_media_by_name() {
    # $1: media name
    local d t len l n
    d="$($_CURL -sS "${_SEARCH_URL}$1" -H "Cookie: ${_COOKIE}")"

    t="$($_PUP ".thumbnail" <<< "$d")"
    len="$(grep -c "class=\"thumbnail" <<< "$t")"
    [[ -z "$len" || "$len" == "0" ]] && print_error "Media not found!"

    true > "$_SEARCH_LIST_FILE"
    for i in $(seq 1 "$len"); do
        n="$($_PUP ".thumbnail:nth-child($i) h5 a:nth-child(1) text{}" <<< "$t" | sed_remove_space)"
        l="$($_PUP ".thumbnail:nth-child($i) h5 a:nth-child(1) attr{href}" <<< "$t" | sed_remove_space)"
        echo "[$l] $n" | tee -a "$_SEARCH_LIST_FILE"
    done
}

is_movie() {
    # $1: media path
    [[ "$1" =~ ^/M.* ]] && return 0 || return 1
}

download_source() {
    local d a
    mkdir -p "$_SCRIPT_PATH/$_MEDIA_NAME"
    d="$($_CURL -sS "$_HOST/$_MEDIA_PATH" -H "Cookie: ${_COOKIE}")"
    a="$($_PUP ".alert-info-ex" <<< "$d")"
    if is_movie "$_MEDIA_PATH"; then
        download_media "$_MEDIA_PATH" "$_MEDIA_NAME"
    else
        echo "$a" > "$_SCRIPT_PATH/$_MEDIA_NAME/$_SOURCE_FILE"
    fi
}

download_episodes() {
    # $1: episode number string
    local origel el uniqel se
    origel=()
    if [[ "$1" == *","* ]]; then
        IFS="," read -ra ADDR <<< "$1"
        for n in "${ADDR[@]}"; do
            origel+=("$n")
        done
    else
        origel+=("$1")
    fi

    el=()
    for i in "${origel[@]}"; do
        if [[ "$i" == *"-"* ]]; then
            se=$(awk -F '-' '{print $1}' <<< "$i" | awk -F '.' '{print $1}')
            s=$(awk -F '-' '{print $1}' <<< "$i" | awk -F '.' '{print $2}')
            e=$(awk -F '-' '{print $2}' <<< "$i" | awk -F '.' '{print $2}')
            for n in $(seq "$s" "$e"); do
                el+=("${se}.${n}")
            done
        else
            el+=("$i")
        fi
    done

    IFS=" " read -ra uniqel <<< "$(printf '%s\n' "${el[@]}" | sort -u -V | tr '\n' ' ')"

    [[ ${#uniqel[@]} == 0 ]] && print_error "Wrong episode number!"

    for e in "${uniqel[@]}"; do
        download_episode "$e"
    done
}

download_episode() {
    # $1: episode number
    local l
    l=$(grep "\[$1\] " "$_SCRIPT_PATH/$_MEDIA_NAME/$_EPISODE_LINK_LIST" \
        | awk -F '] ' '{print $2}')
    [[ "$l" != *"/"* ]] && print_error "Wrong download link or episode not found!"
    download_media "$l" "$1"
}

download_media() {
    # $1: media link
    # $2: media name
    local id u h d el sl currdir
    id=$(get_media_id "$1")
    h=$(get_media_host "$1")
    is_movie "$_MEDIA_PATH" && u="GetMInfoAjax" || u="GetEInfoAjax"
    d="$("$_CURL" -sSX POST "${_HOST}/home/index/${u}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Referer: ${_HOST}${1}" \
        -H "Cookie: $_COOKIE" \
        --data "pass=${id}&param=${h}")"
    el="$($_JQ -r '.val' <<< "$d")"
    sl=""
    if [[ "$($_JQ '.subs | length' <<< "$d")" -gt "0" ]]; then
        sl="$($_JQ -r '.subs[]| select(.name == "'"$_SUBTITLE_LANG"'") | .path' <<< "$d")"
    fi

    if [[ -z ${_LIST_LINK_ONLY:-} ]]; then
        if [[ -n "$sl" ]]; then
            print_info "Downloading subtitle $2..."
            $_CURL -L "${_HOST}${sl}" -g \
                -o "$_SCRIPT_PATH/${_MEDIA_NAME}/${2}_${_SUBTITLE_LANG}.srt" \
                -H "Cookie: ${_COOKIE}"
        fi
        if [[ -z ${_DOWNLOAD_SUBTITLE_ONLY:-} ]]; then
            print_info "Downloading video $2..."

            if [[ -z ${_EXTERNAL_COMMAND:-} ]]; then
                $_CURL -L "$el" -g -o "$_SCRIPT_PATH/${_MEDIA_NAME}/${2}.mp4"
            else
                el="${el//\?/\\\?}"
                el="${el//\&/\\\&}"
                currdir="$(pwd)"
                cd "$_SCRIPT_PATH/${_MEDIA_NAME}"
                eval "$_EXTERNAL_COMMAND $el"
                cd "$currdir"
            fi
        fi
    else
        echo "$el"
    fi
}

create_episode_list() {
    local slen elen sf t l sn se et el
    sf="$_SCRIPT_PATH/$_MEDIA_NAME/$_SOURCE_FILE"
    el="$_SCRIPT_PATH/$_MEDIA_NAME/$_EPISODE_LINK_LIST"
    et="$_SCRIPT_PATH/$_MEDIA_NAME/$_EPISODE_TITLE_LIST"
    slen="$(grep 'alert alert-info-ex' -c "$sf")"
    true > "$et"
    true > "$el"
    for i in $(seq "$slen" -1 1); do
        sn=$((slen - i + 1))
        elen="$($_PUP ".alert-info-ex:nth-child($i)" < "$sf" | grep -c "myp1\"")"
        for j in $(seq "$elen" -1 1); do
            se=$((elen - j + 1))
            t="$($_PUP ".alert-info-ex:nth-child($i) div:nth-child(4) div:nth-child($j) text{}" < "$sf" | sed_remove_space)"
            l="$($_PUP ".alert-info-ex:nth-child($i) div:nth-child(4) div:nth-child($j) a attr{href}" < "$sf")"
            echo "[${sn}.${se}] $t" >> "$et"
            echo "[${sn}.${se}] $l" >> "$el"
        done
    done
}

select_episodes_to_download() {
    cat "$_SCRIPT_PATH/$_MEDIA_NAME/$_EPISODE_TITLE_LIST" >&2
    echo -n "Which episode(s) to downolad: " >&2
    read -r s
    echo "$s"
}

main() {
    set_args "$@"
    set_var

    local mlist=""
    if [[ -n "${_INPUT_NAME:-}" ]]; then
        mlist="$(search_media_by_name "$_INPUT_NAME")"
        _MEDIA_PATH=$($_FZF -1 <<< "$(sort -u <<< "$mlist")" | awk -F']' '{print $1}' | sed -E 's/^\[//')
    fi

    [[ -z "${_MEDIA_PATH:-}" ]] && print_error "Media not found! Missing option -n <name> or -p <path>?"
    _MEDIA_NAME=$(sort -u "$_SEARCH_LIST_FILE" \
                | grep "$_MEDIA_PATH" \
                | awk -F '] ' '{print $2}' \
                | sed -E 's/\//_/g')

    [[ "$_MEDIA_NAME" == "" ]] && _MEDIA_NAME="$(get_media_name "$_MEDIA_PATH")"

    download_source

    is_movie "$_MEDIA_PATH" && exit 0

    create_episode_list

    [[ -z "${_MEDIA_EPISODE:-}" ]] && _MEDIA_EPISODE=$(select_episodes_to_download)
    download_episodes "$_MEDIA_EPISODE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
