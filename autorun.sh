#!/bin/bash

#-------------------------------------------------------------------------------
# Automatically runs groups of bots defined in directories
#   ./bot-settings-<groupA>
#   ./bot-settings-<groupB>
#   ./bot-settings-<groupC>
#   ...
#
# Options
#   -b index, --bot index
#     Starts running with BOTS[index]
#
#   -t h:m:s, --time h:m:s   
#     Starts with bot having already run for h:m:s
#     -t 2        is equivalent to -t 2:00:00
#     -t 2:30     is equivalent to -t 2:30:00
#     -t 0:0:3600 is equivalent to -t 1:00:00
#-------------------------------------------------------------------------------

# number of hours a bot group is allowed to run per 24h
declare -i MAX_UPTIME=6

# number of pokemon a bot is allowed to catch per 24h
declare -i -r MAX_POKEMON=900

# number of pokestops a bot is allowed to loot per 24h
declare -i -r MAX_POKESTOP=1800

# list of bot groups, defined by the directories bot-settings-<group>
declare -a -r BOTS=(
  "groupA"
  "groupB"
  "groupC"
  "groupD"
)

# number of seconds to wait before restarting bot group
# to allow player to walk back to starting position
declare -i -r WALK_TIME=360

# if a bot has not caught any pokemon in the last NOCATCH_LIMIT minutes, 
# then bot group will restart
declare -i -r NOCATCH_LIMIT=10

# seconds between each bot status check
declare -i -r UPDATE_INTERVAL=10

# command to run bot
declare -r START_BOT="./run.sh"

# command to stop bot
declare -r STOP_BOT="./stop.sh"

# exceptions that require restarting the bot group
declare -a -r EXCEPTIONS=(
  "com.pokegoapi.exceptions.LoginFailedException"
  "com.pokegoapi.exceptions.RemoteServerException"
)

# bot group variables
declare -i BOT_INDEX           # current bot group index
declare -a SECONDS_INITIAL     # initial start time of bot group
declare -a SECONDS_LATEST      # latest start time of bot group
declare -a BOT_NAMES           # names of bots in current bot group

# individual bot variables
declare -a POKEMON_COUNT       # number of pokemon caught (keep < 1000 per 24h)
declare -a POKESTOP_COUNT      # number of pokestops looted (keep < 2000 per 24h)
declare -a INITIAL_XP          # xp for each bot at start of each session

declare XP_LOG                 # return value for update_xp()

# convert seconds to h:m:s
# $1 - seconds
convert_seconds() {
  (( h=${1}/3600 ))
  (( m=(${1}%3600)/60 ))
  (( s=${1}%60 ))
  printf "%02d:%02d:%02d" $h $m $s
}

# log status with timestamp and current running bot group
# $1 - log message
# $2 - (optional) escape sequence added to start of log message
# $3 - (optional) if set, overwrite previous line
log () {
  local now          # timestamp
  local es           # escape sequence

  now=$(date "+%d %b %H:%M:%S")

  if [ "$2" ]; then
    es=$2
  else
    es="\e[0m"
  fi

  if [ "$3" ]; then
    printf "${es}\e[F\e[2K%s [%s] %s\e[0m\n" "$now" "${BOTS[BOT_INDEX]}" "$1"
  else
    printf "${es}%s [%s] %s\e[0m\n" "$now" "${BOTS[BOT_INDEX]}" "$1"
  fi
}

# update bot names
update_names() {
  local s
  
  # not quoting this because it messes up IDE coloring :(
  s=$(grep -h \"name\" bot-settings/* | sed -e 's/"name"//;s/://;s/"//g;s/,//;s/\s//g')  
  IFS=" " read -ra BOT_NAMES <<< "$s"
}

# sets initial xp if not already set, and updates log string
# return XP_LOG
update_xp() {
  local xpline
  local xp
  local xpph
  local profile_seconds
  local current_seconds
  local offset_seconds
  
  # get starting xp if not set
  for i in "${!BOT_NAMES[@]}"; do
    if [[ -z ${INITIAL_XP[i]} ]]; then
      xp="$(grep -m1 Experience log.txt | awk '{print $9}' | sed -s 's/;//')"
      if [[ -n $xp ]]; then
        (( INITIAL_XP[i] = xp ))
      fi
    fi    
  done
  
  # update log
  XP_LOG=""
  for i in "${!BOT_NAMES[@]}"; do
    if [[ -n ${INITIAL_XP[i]} ]]; then
      # get xp at last profile update
      xpline="$(tac log.txt | grep -m1 "\[${BOT_NAMES[i]}: ProfileLoop\] - Profile update:")"
      xp="$(awk '{print $9}' <<< "$xpline")"
      
      # shave off time since last profile update
      IFS=: read h m s <<< "$(awk '{print $3}' <<< "$xpline")"
      profile_seconds=$(( 10#$s + 10#$m*60 + 10#$h*3600 ))
      current_seconds=$(( 10#$(date +"%H")*3600 + 10#$(date +"%M")*60 + 10#$(date +"%S") ))
      offset_seconds=$(( current_seconds - profile_seconds ))

      # update xp/hr
      if (( xp > INITIAL_XP[i] )); then
        # xp *should* never be set when SECONDS == SECONDS_INITIAL
        xpph=$(( 3600 * (xp - INITIAL_XP[i]) / (SECONDS - SECONDS_INITIAL[BOT_INDEX] - offset_seconds) ))
      else
        xpph=0
      fi
      xpph=$(printf "%'d" $xpph)
      [[ -z $XP_LOG ]] && XP_LOG="XP/hr $xpph" || XP_LOG="${XP_LOG}/$xpph"
    fi
  done
    
  if [[ -z $XP_LOG ]]; then
    XP_LOG="XP/hr --"
  fi
}

# update pokemon caught and pokestops looted
udpate_pokes() {
  for i in "${!BOT_NAMES[@]}"; do
    (( POKEMON_COUNT[i]+=$(grep "\[${BOT_NAMES[i]}: BotLoop\] - Caught" log.txt | wc -l) ))
    (( POKESTOP_COUNT[i]+=$(grep "\[${BOT_NAMES[i]}: PokestopLoop\] - Looted" log.txt | wc -l) ))
  done  
}

# restart bot group
# $1 - reason for restart
# $2 - escape sequence for log
# $3 - (optional) if set, increment bot group
restart_bot () {
  local -i time_wait            # time to wait between stop and start
  local stop_result             # output from stop.sh
  local start_bots              # list of bots in bot group

  # stop bot group
  log "Stopping bot. Reason: $1" $2
  log "$(eval $STOP_BOT)"

  # increment bot group
  if [[ "$3" ]]; then
    unset POKEMON_COUNT
    unset POKESTOP_COUNT
    unset INITIAL_XP
    (( BOT_INDEX++ ))
    (( BOT_INDEX %= ${#BOTS[@]} ))
    rm bot-settings/*
    cp bot-settings-${BOTS[BOT_INDEX]}/* bot-settings/
  fi
    
  # wait before restarting
  if [[ "$3" ]]; then
    # check if it has been 24h since the next bot ran. if not, sleep until then.
    time_wait=$(( 86400 - (SECONDS - SECONDS_INITIAL[BOT_INDEX]) ))
    if (( SECONDS_INITIAL[BOT_INDEX] > 0 && time_wait > 0 )); then
      log "Less than 24h since last run. Waiting for ${time_wait}s." "\e[31m"
      sleep ${time_wait}s
    fi
  else
    # check if we need to wait for player to walk back to starting area
    time_wait=$(( (SECONDS - SECONDS_LATEST[BOT_INDEX]) < WALK_TIME ? (SECONDS - SECONDS_LATEST[BOT_INDEX]) : WALK_TIME ))
    if (( SECONDS_LATEST[BOT_INDEX] > 0 )); then
      log "Player walking back to start area. Waiting for ${time_wait}s." "\e[33m"
      sleep ${time_wait}s
    fi      
  fi
  
  # get bot names
  update_names
  
  # start bot group
  start_bots=""
  for bot in "${BOT_NAMES[@]}"; do
    [[ -z "$start_bots" ]] && start_bots="$bot" || start_bots="${start_bots}, $bot"
  done
  log "Starting bot: $start_bots"
  log ""
  eval $START_BOT
  
  # update trackers
  SECONDS_LATEST[BOT_INDEX]=$SECONDS
  if [[ "$3" ]]; then
    SECONDS_INITIAL[BOT_INDEX]=$SECONDS
  fi
}

# main loop
main () {
  local -i bot_uptime           # uptime of current bot group
  local -i num_files            # number of .json files in bot group
  local -i pokemon              # number of pokemon caught in current session
  local -i pokestop             # number of pokestops looted in current session
  local -i bot_offset           # initial bot offset, supplied in args
  
  # option parsing
  local key
  local h
  local m
  local s

  # defaults
  BOT_INDEX=0
  bot_offset=0
  
  # parse options
  while [[ $# -gt 1 ]]; do
    key="$1"
    case $key in
      -b|--bot)
        (( i++ ))
        BOT_INDEX="$2"
        shift
        ;;
      -t|--time)
        (( i++ ))
        IFS=: read h m s <<< "$2"
        bot_offset=$(( -(10#$s + 10#$m*60 + 10#$h*3600) ))
        shift
        ;;
      *)
        ;;
    esac
    shift
  done
    
  # initialize trackers
  (( MAX_UPTIME*=3600 ))
  for i in "${!BOTS[@]}"; do
    SECONDS_INITIAL[i]=0
    SECONDS_LATEST[i]=0
  done

  # initial bot group
  rm bot-settings/*
  cp bot-settings-${BOTS[BOT_INDEX]}/* bot-settings/
  update_names
  start_bots=""
  for bot in "${BOT_NAMES[@]}"; do
    [[ -z $start_bots ]] && start_bots="$bot" || start_bots="${start_bots}, $bot"
  done
  log "Starting bot: $start_bots"
  log ""
  eval $START_BOT
  sleep 1s                     # give time trackers non-zero values
  SECONDS_INITIAL[BOT_INDEX]=$(( SECONDS + bot_offset ))
  SECONDS_LATEST[BOT_INDEX]=$(( SECONDS + bot_offset ))

  while true; do
    # update uptime
    bot_uptime=$(( SECONDS - SECONDS_INITIAL[BOT_INDEX] ))
    
    # get initial xp if not already set
    update_xp
    
    # if maxtime reached, stop current bot and start next bot
    if (( bot_uptime > MAX_UPTIME )); then
      restart_bot "Maximum running time reached" "\e[92m" 1
    fi
        
    # check for login errors at start
    if grep -q MainKt.startBot err.txt; then
      restart_bot "Exception MainKt.startBot" "\e[93m"
    fi

    # check for ban error - https://github.com/Grover-c13/PokeGOAPI-Java/commit/2712436999293533f4df26104c9b4f1d5419f95b
    if grep -q "Your account may be banned" err.txt; then
      udpate_pokes
      restart_bot "Your account may be banned" "\e[41m\e[1m"
    fi
    
    # check for critical errors
    for e in "${EXCEPTIONS[@]}"; do
      if grep -q "$e" err.txt; then
        udpate_pokes
        restart_bot "Exception $e" "\e[91m"
      fi
    done
    
    # if no pokemon caught recently, restart bot
    if (( SECONDS_LATEST[BOT_INDEX] > 0 && (SECONDS - SECONDS_LATEST[BOT_INDEX]) > 120 )); then
      current_seconds=$(( 10#$(date +"%H")*3600 + 10#$(date +"%M")*60 + 10#$(date +"%S") ))
      for i in "${!BOT_NAMES[@]}"; do
        s="$(tac log.txt | grep -m1 "\[${BOT_NAMES[i]}: BotLoop\] - Caught" | awk '{print $3}')"
        IFS=: read h m s <<< "$s"
        caught_seconds=$(( 10#$s + 10#$m*60 + 10#$h*3600 ))
        if (( current_seconds < caught_seconds )); then
          (( current_seconds+=86400 ))
        fi
        if (( (current_seconds - caught_seconds) > NOCATCH_LIMIT * 60 )); then
          udpate_pokes
          restart_bot "No recently caught pokemon" "\e[96m"
        fi
      done
    fi

    # if max pokemon caught or max pokestop looted, restart bot
    pokemon_log=""
    pokestop_log=""
    for i in "${!BOT_NAMES[@]}"; do
      pokemon=$(( POKEMON_COUNT[i] + $(grep "\[${BOT_NAMES[i]}: BotLoop\] - Caught" log.txt | wc -l) ))
      if (( pokemon >= MAX_POKEMON )); then
        restart_bot "Pokemon catch limit reached" "\e[95m" 1
      fi
      pokestop=$(( POKESTOP_COUNT[i] + $(grep "\[${BOT_NAMES[i]}: PokestopLoop\] - Looted" log.txt | wc -l) ))
      if (( pokestop >= MAX_POKESTOP )); then
        restart_bot "Pokestop loot limit reached" "\e[95m" 1
      fi
      [[ -z "$pokemon_log" ]] && pokemon_log="$pokemon" || pokemon_log="${pokemon_log}/$pokemon"
      [[ -z "$pokestop_log" ]] && pokestop_log="$pokestop" || pokestop_log="${pokestop_log}/$pokestop"
    done
      
    log "Played $(convert_seconds $bot_uptime); Left $(convert_seconds $((MAX_UPTIME - bot_uptime))); \
Done $(bc <<< "scale=2; 100*${bot_uptime}/${MAX_UPTIME}")%; Pmon $pokemon_log; Pstop $pokestop_log; $XP_LOG" "\e[1m" 1
    sleep ${UPDATE_INTERVAL}s
  done  
}

main "$@"
