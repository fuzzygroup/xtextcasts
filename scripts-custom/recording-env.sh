if [ -n "$ZSH_VERSION" ]; then
  # Nothing to do
elif [ -n "$BASH_VERSION" ]; then
  PROMPT_COMMAND="precmd"
else
  echo "Only bash or zsh supported"
  exit 1
fi

STATE_NOT_SET=0
STATE_RECORDING=1
STATE_COMPLETED=2

INIT_DIR=''


function set_state_str {
  case $STATE in
    $STATE_COMPLETED)
      STATE_STR="(completed)"
      ;;
    $STATE_RECORDING)
      STATE_STR="(recording)"
      ;;
    *)
      STATE_STR="(not set)"
  esac
}


function init_prompt {
  PWD="$(pwd)"
  if [[ "$INIT_DIR" == "$PWD" ]] ; then
    return
  fi
  echo "Initializing for $PWD"
  INIT_DIR="$PWD"

  EPISODE_NUMBER=$(basename $(readlink -f .) | grep -o '^[0-9]\{3\}-' | grep -o '[0-9]\+')
  if [[ "$EPISODE_NUMBER" == "" ]] ; then
    return
  fi

  LAST_CHUNK_NUMBER=$(ls | grep -o "^$EPISODE_NUMBER-[0-9]\+" | sort -r | uniq | head -1 | grep -o '[0-9]\+$')

  if [[ "$LAST_CHUNK_NUMBER" == "" ]] ; then
    STATE=0
    CHUNK_NUMBER=0
    CHUNK_NAME=
  else
    STATE=$STATE_COMPLETED
    CHUNK_NUMBER=$LAST_CHUNK_NUMBER
    CHUNK_NAME=$(ls | grep "^$EPISODE_NUMBER-$CHUNK_NUMBER-" | head -1 | sed 's/[0-9]\+-[0-9]\+-\([^\.]*\).*$/\1/')
  fi
}

function set_prompt {
  if [[ "$EPISODE_NUMBER" == "" ]] ; then
    PS1="$(pwd) <not supported> $ "
    return
  fi

  if [[ $CHUNK_NUMBER == "0" ]] ; then
    CHUNK_NUMBER_STR="XXX"
  else
    CHUNK_NUMBER_STR="$(printf "%03d" $CHUNK_NUMBER)"
  fi

  set_state_str

  CHUNK_NAME_STR="$CHUNK_NAME"
  if [[ "$CHUNK_NAME_STR" == "" ]] ; then
    CHUNK_NAME_STR="<not set>"
  fi
  CHUNK_FILENAME="$EPISODE_NUMBER-$CHUNK_NUMBER_STR-$CHUNK_NAME_STR"
  PS1="$EPISODE_NUMBER-$CHUNK_NUMBER_STR-$CHUNK_NAME_STR $STATE_STR $ "
}

function rec {
  if [[ "$1" == "" ]] ; then
    echo "Usage: record <chunk_name>"
    return
  fi

  if [[ "$STATE" == "$STATE_RECORDING" ]] ; then
    PENDING_FILES=$(ls | grep "^$EPISODE_NUMBER-$CHUNK_NUMBER_STR-")
    if [[ "$PENDING_FILES" != "" ]] ; then
      echo "ERROR: Pending files! Remove files first"
      echo "$PENDING_FILES"
      return
    fi
    CHUNK_NAME="$1"
    return
  fi
  STATE=$STATE_RECORDING
  CHUNK_NAME="$1"
  CHUNK_NUMBER=$(( $CHUNK_NUMBER + 1 ))
}
function c {
  if [[ $STATE != $STATE_RECORDING ]] ; then
    echo "Not in recording state. Issue record <chunk_name> first"
    return
  fi
  if [[ "$CHUNK_NAME" == "" ]] ; then
    echo "Chunk name not set"
    return
  fi
  echo "Recording: $CHUNK_FILENAME"
  TOP=51 ../../Homepage/scripts-custom/capture.sh "$CHUNK_FILENAME.mp4"
}

function rerecord {
  STATE=$STATE_RECORDING
}
function f {
  if [[ $STATE != $STATE_RECORDING ]] ; then
    echo "Not in recording state."
    return
  fi
  STATE=$STATE_COMPLETED
  ../../Homepage/scripts-custom/remove_noise.sh "$CHUNK_FILENAME.mp4"
}
function help {
  echo "rec <chunk_name>    - set new chunk to record"
  echo "rerecord            - record last chuck again"
  echo "c                   - capture chunk"
  echo "f                   - finish chunk"
  echo "v                   - view last recorded chunk"
}

function precmd {
  init_prompt
  set_prompt
}

help

alias record=rec
alias capture=c
alias finish=f
alias v='vlc $CHUNK_FILENAME.mp4'
