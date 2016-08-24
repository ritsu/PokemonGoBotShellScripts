#!/bin/bash

# displays profileloop lines in log.txt
# $1 (optional) name of bot

if [ "$#" -eq 1 ]; then
        grep "\[$1: ProfileLoop" log.txt
else
        grep "\ProfileLoop" log.txt
fi

tput sgr0
