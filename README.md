# audio-control
Script to control audio players like: audacious, mocp. mpris-remote compliant audio players are also supported.

## Author: Anjishnu Sarkar
## Usage: 
    audio-control.sh [options]

    Options:
    -h|--help             Show this help and exit.
    -a|--action <action>  Act on the active player.
    List of supported actions are:
    play, playpause, pause, stop, next, previous, info
  
# Requirements
notify-send.sh from https://github.com/vlevit/notify-send.sh and
mpris-remote from https://github.com/mackstann/mpris-remote

# Installation

    mkdir -p ~/bin/

    sudo apt-get install bash libglib2.0-bin
    git clone https://github.com/vlevit/notify-send.sh.git
    cd notify-send.sh
    cp notify-action.sh ~/bin/
    cp notify-send.sh ~/bin/

    sudo apt install python-dbus
    git clone git://github.com/mackstann/mpris-remote.git
    cd mpris-remote
    cp mpris-remote ~/bin/

    # Download and copy the current script audio-control.sh to ~/bin/
