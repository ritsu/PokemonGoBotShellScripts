#!/bin/bash

# displays botloop lines in log.txt
# $1 (optional) name of bot

if [ "$#" -eq 1 ]; then
        grep "\[$1: BotLoop" log.txt
else
        grep "\BotLoop" log.txt
fi

tput sgr0
