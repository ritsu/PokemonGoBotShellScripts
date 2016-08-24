#!/bin/bash

java_process=$(pgrep -lf java.*PokemonGoBot)

if [ "$java_process" ]; then
  printf "killing $java_process... "
  pkill -f java.*PokemonGoBot
  printf "$?"
  while pgrep -lf java.*PokemonGoBot >/dev/null; do
    if (( SECONDS > 6 )); then
      pkill -9 -f java.*PokemonGoBot
      printf "$?"
      break
    fi
    sleep 1s
  done
  printf "\n"
else
  printf "java process not found\n"
fi


