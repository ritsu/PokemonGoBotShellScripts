#!/bin/bash

# displays log.txt stream
# $1 (optional) name of bot, removes some less important lines
# $2 (optional) number of initial lines to display

if [ "$#" -eq 1 ]; then
  tail -f log.txt | grep --line-buffered "\[$1:" | grep --line-buffered -v WalkingLoop | grep --line-buffered -v Getting
elif [ "$#" -eq 2 ]; then
  tail -f -n $2 log.txt | grep --line-buffered "\[$1:" | grep --line-buffered -v WalkingLoop | grep --line-buffered -v Getting
else
  tail -f -n 200 log.txt
fi

