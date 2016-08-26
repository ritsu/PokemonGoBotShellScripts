# PokemonGoBotShellScripts

A few shell scripts to help manage [PokemonGoBot](https://github.com/jabbink/PokemonGoBot)

Automatically runs groups of bots. Will stop and move on to the next group when time limit, pokemon caught limit, or pokestop loot limit are reached. When cycling back to first bot group, will hold until 24 hrs has passed since last session.

## Requirements

Any system that can run bash scripts. 
Tested on Linux.
May run on Windows with Cygwin or MinGW MSYS, but untested.  

## Setup

Download files.  
`chmod +x *.sh`  
Modify `run.sh` to point to your jar file (and remove --spring.main.web-environment=false if you want).  
Put your [JSON files](https://github.com/jabbink/PokemonGoBot/blob/develop/json-template.json) in separate directories named <i>bot-settings-xxx</i> where <i>xxx</i> can be anything. If a directory has multiple JSON files, they will be run together as a bot group.  
Define the `BOTS` array in `autorun.sh` according to the directories you created above.  
Change other settings in `autorun.sh` as you see fit.  

!!! <b>IMPORTANT</b> - Make sure you move ALL your JSON files out from <i>bot-settings</i> into <i>bot-settings-xxx</i>, as the <i>bot-settings</i> directory is cleared each time a new bot group is run.  

## Usage

```
./arun.sh  
./acheck.sh  
./astop.sh
```

`arun.sh` calls `autorun.sh` via [nohup](https://en.wikipedia.org/wiki/Nohup) for convenience when running bots on remote servers.  
Command line arguments to `arun.sh` are explained in `autorun.sh`

## Notes

####check.sh
View the live output of the currently running bot(s).

####check-profile.sh
View ProfileLoop output from currently running bot(s).

####check-bot.sh
View BotLoop output from currently running bot(s).

####acheck.sh
When writing to `alog.txt`, `\033[F` is used to overwrite the previous line when displaying repetitive status updates. Terminal windows that are too small, or file viewers that don't interpret escape codes (e.g. `less` without the `-r` flag) may have issues.



