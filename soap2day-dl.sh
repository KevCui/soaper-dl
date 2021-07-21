#!/usr/bin/env bash
#
# Download TV series and Movies from Soap2day using CLI
#
#/ Usage:
#/   ./soap2day-dl.sh [-n <name>] [-p <path>] [-e <num1,num2,num3-num4...>] [-l] [-s]
#/
#/ Options:
#/   -n <name>               TV series or Movie name
#/   -p <path>               Media path
#/                           e.g: /tv_XXXXXXXX.html
#/                           ingored when "-n" is enabled
#/   -e <num1,num3-num4...>  Optional, episode number to download
#/                           e.g: episode number "3.2" means Season 3 Episode 2
#/                           multiple episode numbers seperated by ","
#/                           episode range using "-"
#/   -l                      Optional, list video link only without downloading
#/   -s                      Optional, download subtitle only
#/   -h | --help             Display this help message

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
    _CHROME="$(command -v chrome \
        || command -v chromium \
        || return_default_chrome_path)" \
        || command_not_found "chrome"

    _HOST="https://soap2day.to"
    _SEARCH_URL="$_HOST/search.html?keyword="

    _SCRIPT_PATH=$(dirname "$(realpath "$0")")
    _SEARCH_LIST_FILE="$_SCRIPT_PATH/search.list"
    _SOURCE_FILE=".source.html"
    _EPISODE_LINK_LIST=".episode.link"
    _EPISODE_TITLE_LIST=".episode.title"
    _SUBTITLE_LANG="${SOAP2DAY_SUBTITLE_LANG:-English}"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        _USER_AGENT="Mozilla/5.0 ((Macintosh; Intel Mac OS X 11_4_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$($_CHROME --version | awk '{print $2}') Safari/537.36"
    else
        _USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$($_CHROME --version | awk '{print $2}') Safari/537.36"
    fi

    _CF_JS_SCRIPT="$_SCRIPT_PATH/bin/getCFcookie.js"
    [[ ! -s "${_CF_JS_SCRIPT:-}" ]] && \
        print_error "Cannot find ${_CF_JS_SCRIPT} or it's empty!"
    _CF_FILE="$_SCRIPT_PATH/cf_clearance"
    touch "$_CF_FILE"
    _CF_CLEARANCE="$(cat "$_CF_FILE")"
}

set_args() {
    expr "$*" : ".*--help" > /dev/null && usage
    while getopts ":hlsn:p:e:" opt; do
        case $opt in
            n)
                _INPUT_NAME="$OPTARG"
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

return_default_chrome_path() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    else
        echo "/usr/bin/chrome"
    fi
}

sed_remove_space() {
    sed -E '/^[[:space:]]*$/d;s/^[[:space:]]+//;s/[[:space:]]+$//'
}

get_cf() {
    # $1: url
    local cf
    print_info "Wait 5s for fetching cf_clearance..."
    cf="$($_CF_JS_SCRIPT -u "$1" -a "$_USER_AGENT" -p "$_CHROME" "${2:-}" \
        | $_JQ -r '.[] | select(.name == "cf_clearance") | .value')"
    if [[ -z "${cf:-}" ]]; then
        get_cf "$_HOST" "-s"
    else
        echo "$cf" | tee "$_CF_FILE"
    fi
}

renew_cf() {
    local s
    s="$("$_CURL" -sS -I "$_HOST" \
        -H "User-Agent: ${_USER_AGENT}" \
        -H "Cookie: cf_clearance=${_CF_CLEARANCE:-}" \
        | head -1)"
    if [[ "$s" == *"50"* ]]; then
        _CF_CLEARANCE="$(get_cf "$_HOST")"
    fi
}

get_media_id() {
    # $1: URL
    renew_cf
    $_CURL -sS "${_HOST}${1}" \
        -H "User-Agent: ${_USER_AGENT}" \
        -H "Cookie: cf_clearance=${_CF_CLEARANCE}" \
    | $_PUP "#hId attr{value}"
}

get_media_name() {
    # $1: media link
    renew_cf
    $_CURL -sS "${_HOST}${1}" \
        -H "User-Agent: ${_USER_AGENT}" \
        -H "Cookie: cf_clearance=${_CF_CLEARANCE}" \
    | $_PUP ".panel-body h4 text{}" \
    | head -1 \
    | sed_remove_space
}

search_media_by_name() {
    # $1: media name
    local d t len l n
    renew_cf
    d="$($_CURL -sS "${_SEARCH_URL}$1" \
            -H "User-Agent: ${_USER_AGENT}" \
            -H "Cookie: cf_clearance=${_CF_CLEARANCE}")"

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
    renew_cf
    d="$($_CURL -sS "$_HOST/$_MEDIA_PATH" \
            -H "User-Agent: ${_USER_AGENT}" \
            -H "Cookie: cf_clearance=${_CF_CLEARANCE}")"
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
    local id u p d el sl
    id=$(get_media_id "$1")
    if is_movie "$_MEDIA_PATH"; then
        u="${_HOST}/home/index/GetMInfoAjax"
        p="https%3A%2F%2Fm1.wewon.to"
    else
        u="${_HOST}/home/index/GetEInfoAjax"
        p="https%3A%2F%2Ff1.wewon.to"
    fi
    renew_cf
    d="$($_CURL -sSX POST "$u" \
        -H "User-Agent: ${_USER_AGENT}" \
        -H "Cookie: cf_clearance=${_CF_CLEARANCE}" \
        -H "Referer: ${_HOST}${1}" \
        --data "pass=${id}&param=${p}")"
    el="$($_JQ -r '.val' <<< "$d")"
    sl=""
    if [[ "$($_JQ '.subs | length' <<< "$d")" -gt "0" ]]; then
        sl="$($_JQ -r '.subs[]| select(.name == "'"$_SUBTITLE_LANG"'") | .path' <<< "$d")"
    fi

    if [[ -z ${_LIST_LINK_ONLY:-} ]]; then
        if [[ -n "$sl" ]]; then
            print_info "Downloading subtitle $2..."
            renew_cf
            $_CURL -L "${_HOST}${sl}" -g -o "$_SCRIPT_PATH/${_MEDIA_NAME}/${2}_${_SUBTITLE_LANG}.srt" \
                -H "User-Agent: ${_USER_AGENT}" \
                -H "Cookie: cf_clearance=${_CF_CLEARANCE}"
        fi
        if [[ -z ${_DOWNLOAD_SUBTITLE_ONLY:-} ]]; then
            print_info "Downloading video $2..."
            $_CURL -L "$el" -g -o "$_SCRIPT_PATH/${_MEDIA_NAME}/${2}.mp4"
        fi
    else
        echo "$el" >&2
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

    if [[ -n "${_INPUT_NAME:-}" ]]; then
        _MEDIA_PATH=$($_FZF -1 <<< "$(search_media_by_name "$_INPUT_NAME")" \
                                    | awk -F']' '{print $1}' \
                                    | sed -E 's/^\[//')
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
