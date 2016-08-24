#!/bin/bash

java_process=$(pgrep -lf java.*PokemonGoBot)

if [ "$java_process" ]; then
  printf "killing $java_process... "
  pkill -9 -f java.*PokemonGoBot
  printf "$?\n"
else
  printf "java process not found\n"
fi


