#!/bin/bash

sh_process=$(pgrep -l autorun.sh)
if [ "$sh_process" ]; then
  printf "killing $sh_process... "
  pkill autorun.sh
  printf "$?\n"
else
  printf "autorun.sh process not found\n"
fi

java_process=$(pgrep -lf java.*PokemonGoBot)
if [ "$java_process" ]; then
  printf "killing $java_process... "
  pkill -9 -f java.*PokemonGoBot
  printf "$?\n"
else
  printf "java process not found\n"
fi
