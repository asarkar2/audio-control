#!/bin/bash

# Requires
# notify-send.sh from https://github.com/vlevit/notify-send.sh
# mpris-remote from https://github.com/mackstann/mpris-remote

function check_software(){

    eval "declare -a require="${1#*=}

    # Declare app to be a local variable
    local app

    for app in "${require[@]}"
    do
        if [ -z $(which ${app}) ];then
            echo "The software \"${app}\" NOT found. Aborting."
            exit 1
        fi
    done
}

# https://stackoverflow.com/questions/1527049/join-elements-of-an-array
function join(){
    local d=$1
    shift
    echo -n "$1"
    shift
    printf "%s" "${@/#/$d}"
}

# Helptext
function helptext(){

    local sname="$1"
    local au="$2"
    local ver="$3"
    eval "declare -a all_players="${4#*=}
    eval "declare -a all_actions="${5#*=}

    local lstplyrs=$(join ', ' "${all_players[@]}")
    local lstsprt=$(join ', ' "${all_actions[@]}")

    echo -n "Script to control audio players like: "
    echo "$lstplyrs"
    echo "mpris-remote compliant audio players are also supported."
    echo "Author: "${au}""
    echo "Version: "${ver}""
    echo ""
    echo "Usage: $sname [options]"
    echo ""
    echo "Options:"
    echo "-h|--help             Show this help and exit."
    echo "-a|--action <action>  Act on the active player."
    echo "List of supported actions are:"
    echo "$lstsprt"

}

# Get playername
function get_player(){

    eval "declare -a all_players="${1#*=}

    for plyr in "${all_players[@]}"
    do
        if ps -A | grep "$plyr" > /dev/null 2>&1; then
            echo "$plyr"
            return
        fi
    done

    # Check if mpris-remote compliant audio player is active or not
    mpris-remote identity >> /dev/null 2>&1
    local rtn=$(echo $?)
    if [ $rtn -eq 0 ];then
        echo "mpris_remote"
        return
    fi

    echo "unsupported"
    return
}

function progressbar(){

    local act="$1"
    local delay="$2"
    local i="$3"

    if [ $act = "info" ];then
        notify-send.sh -t "$delay" " " --hint int:value:$i \
            --replace-file "/tmp/audio-control-bar" &
    fi
}

function get_album_cover(){

    local file="${1}"
    local album_cover="${2}"
    local icon="${3}"

    local folder=$(dirname "$file")
    local folder_img_path="$folder/$album_cover"

    if [ -e "$folder_img_path" ]; then
        mkdir -p "$HOME"/.pixmaps/
        cp "$folder_img_path" "$HOME"/.pixmaps/
        local image=""$HOME"/.pixmaps/"$album_cover""
    else
        local image="$icon"
    fi

    echo "${image}"
    return
}


# Send mocp notification
function notification(){

    local act="$1"
    eval "declare -A params="${2#*=}
    eval "declare -A info="${3#*=}

    local icon="${params['icon']}"
    local album_cover="${params['album_cover']}"
    local delay="${params['delay']}"

    local state="${info['state']}"
    local player="${info['player']}"

    if [ "$state" = 'Playing' ]; then

        local title="${info['title']}"
        local artist="${info['artist']}"
        local album="${info['album']}"
        local file="${info['file']}"
        local totalsec="${info['totalsec']}"
        local currentsec="${info['currentsec']}"

        local i=$(echo "($currentsec*100)/$totalsec" | bc)

        local image=$(get_album_cover "${file}", "${album_cover}" "${icon}")

        notify-send.sh "${title}" "${artist}\n${album}" -i "$image" \
            -t "$delay" --replace-file "/tmp/audio-control-text" && \
            progressbar "$act" "$delay" "$i" &

    elif [ "$state" = 'Paused' ] || [ "$state" = 'Stopped' ]; then

        notify-send.sh "${player}" "${state}" -i "$icon" \
            -t "$delay" --replace-file "/tmp/audio-control-text" &

    fi
    return
}


function info_audacious(){

    local state=$(audtool playback-status)
    state=$(echo ${state^}) # Uppercase 1st letter

    local title=$(audtool current-song-tuple-data title)
    local artist=$(audtool current-song-tuple-data artist)
    local album=$(audtool current-song-tuple-data album)
    local file=$(audtool current-song-filename)
    local totalsec=$(audtool current-song-length-seconds)
    local currentsec=$(audtool current-song-output-length-seconds)

    declare -A dict=( ['player']="Audacious"
                      ['state']="${state}"
                      ['title']="${title}"
                      ['artist']="${artist}"
                      ['album']="${album}"
                      ['file']="${file}"
                      ['totalsec']="${totalsec}"
                      ['currentsec']="${currentsec}"
                    )

    # Return a dictionary
    echo '('
    for key in  "${!dict[@]}" ; do
        echo "['$key']=\"${dict[$key]}\""
    done
    echo ')'
}

# Get information for a particular key
function get_key_info(){

    local key="${1}"
    local info_all="${2}"

    local value=$(echo "${info_all}" | grep -w "${key}" | sed "s/${key}://" \
            | sed 's/^ //g' | sed 's/ $//g')
    echo "${value}"
    return
}

# Get the moc playing state
function get_mocp_state(){

    local m_state="${1}"

    if [ "${m_state}" == 'PLAY' ];then
        echo "Playing"
    elif [ "${m_state}" == 'PAUSE' ];then
        echo "Paused"
    elif [ "${m_state}" == 'STOP' ];then
        echo "Stopped"
    fi

    return
}


function info_mocp(){

    local info_all=$(mocp --info)

    local mocp_state=$(get_key_info "State" "${info_all}")
    local state=$(get_mocp_state "${mocp_state}")

    local title=$(get_key_info "SongTitle" "${info_all}")
    local artist=$(get_key_info "Artist" "${info_all}")
    local album=$(get_key_info "Album" "${info_all}")
    local file=$(get_key_info "File" "${info_all}")
    local totalsec=$(get_key_info "TotalSec" "${info_all}")
    local currentsec=$(get_key_info "CurrentSec" "${info_all}")

    declare -A dict=( ['player']="MOC"
                      ['state']="${state}"
                      ['title']="${title}"
                      ['artist']="${artist}"
                      ['album']="${album}"
                      ['file']="${file}"
                      ['totalsec']="${totalsec}"
                      ['currentsec']="${currentsec}"
                    )

    # Return a dictionary
    echo '('
    for key in  "${!dict[@]}" ; do
        echo "['$key']=\"${dict[$key]}\""
    done
    echo ')'
}


function get_mpris_currentsec(){

    local position=$(mpris-remote position)
    local min=$(echo "$position" | cut -d: -f1)
    local sec=$(echo "$position" | cut -d: -f2 | cut -d\. -f1)
    local currentsec=$(echo "($min*60) + $sec" | bc)

    echo $currentsec
    return
}

function info_mpris_remote(){

    local player=$(mpris-remote identity | cut -d" " -f1)

    local info_all=$(mpris-remote trackinfo)

    local state=$(mpris-remote playstatus | head -n1 | cut -d: -f2 \
                    | sed 's/^ //')
    state=$(echo ${state^}) # Uppercase 1st letter

    local title=$(get_key_info "title" "${info_all}")
    local artist=$(get_key_info "artist" "${info_all}")
    local album=$(get_key_info "album" "${info_all}")

    local location=$(get_key_info "location" "${info_all}")
    local file=$(echo "${location}" | sed 's/file:\/\///')

    local itime=$(get_key_info "time" "${info_all}")
    local totalsec=$(echo "$itime" | sed 's/ .*//')

    local currentsec=$(get_mpris_currentsec)

    declare -A dict=( ['player']="${player}"
                      ['state']="${state}"
                      ['title']="${title}"
                      ['artist']="${artist}"
                      ['album']="${album}"
                      ['file']="${file}"
                      ['totalsec']="${totalsec}"
                      ['currentsec']="${currentsec}"
                    )

    # Return a dictionary
    echo '('
    for key in  "${!dict[@]}" ; do
        echo "['$key']=\"${dict[$key]}\""
    done
    echo ')'
}

# Support for audacious
function action_audacious(){

    local act="$1"
    eval "declare -A params="${2#*=}

    case "$act" in
        playpause)  audtool playback-playpause
                    return 0                    ;;

        pause)      audtool playback-pause
                    return 0                    ;;

        stop)       audtool playback-stop
                    return 0                    ;;

        play)       audtool playback-play
                    return 0                    ;;

        next)       audtool playback-advance
                    return 0                    ;;

        previous)   audtool playback-reverse
                    return 0                    ;;

        info)                                   ;;

    esac

    declare -A info="$(info_audacious)"
    notification "$act" "$(declare -p params)" "$(declare -p info)"

    return 0
}

# Support for mocp
function action_mocp(){

    local act="$1"
    eval "declare -A params="${2#*=}

    case "$act" in
        playpause)  mocp --toggle-pause ;;
        pause)      mocp --pause        ;;
        stop)       mocp --stop         ;;
        play)       mocp --play         ;;
        next)       mocp --next         ;;
        previous)   mocp --previous     ;;
        info)                           ;;
    esac

    declare -A info="$(info_mocp)"
    notification "$act" "$(declare -p params)" "$(declare -p info)"

    return 0
}

function action_mpris_remote(){

    local act="$1"
    eval "declare -A params="${2#*=}

    case "$act" in
        playpause)  mpris-remote pause      ;;
        pause)      mpris-remote pause      ;;
        stop)       mpris-remote stop       ;;
        play)       mpris-remote play       ;;
        next)       mpris-remote next       ;;
        previous)   mpris-remote previous   ;;
        info)                               ;;
    esac

    declare -A info="$(info_mpris_remote)"
    notification "$act" "$(declare -p params)" "$(declare -p info)"

    return 0
}

# Check if action is supported or not
function check_action(){

    local act="${1}"
    eval "declare -a array="${2#*=}

    for str in "${array[@]}"
    do
        if [ "${str}" == "${act}" ];then
            return
        fi
    done

    echo "Action \""${act}"\" not supported. Aborting."
    exit 1
}

scriptname=$(basename $0)
author="Anjishnu Sarkar"
version="0.10"
requirements=("notify-send.sh")
audio_players=("audacious" "mocp")
support=('play' 'playpause' 'pause' 'stop' 'next' 'previous' 'info')

# Declare the parameters
icon="multimedia-audio-player"
album_cover="folder.jpg"
delay="3000"    # Notification display time
declare -A parameters=( ['icon']="${icon}"
                        ['album_cover']="${album_cover}"
                        ['delay']="${delay}"
                      )

# Loop over the cli arguments
while test -n "$1"
do
    case "$1" in
        -h|--help)  helptext ${scriptname} "${author}" ${version} \
                        "$(declare -p audio_players)" \
                        "$(declare -p support)"
                    exit 0
                    ;;

        -a|--action) action="${2}"
                    shift
                    ;;

        *)          echo "Undefined parameter passed. Aborting."
                    exit 1
                    ;;
    esac
    shift
done

check_software "$(declare -p requirements)"

# Check if action is supported or not
check_action "${action}" "$(declare -p support)"

# playername=$(get_player "${audio_players[@]}")
playername=$(get_player "$(declare -p audio_players)")

case ${playername} in

    audacious)      action_audacious ${action} "$(declare -p parameters)" ;;

    mocp)           action_mocp ${action} "$(declare -p parameters)" ;;

    mpris_remote)   action_mpris_remote ${action} "$(declare -p parameters)"
                    ;;

    unsupported)    text="No supported audio players found.\nAborting."

                    notify-send.sh "Audio Control" "$(printf "$text")" \
                        -i "$icon" -t "$delay" \
                        --replace-file "/tmp/audio-control-text" &

                    exit 1
                    ;;
esac

