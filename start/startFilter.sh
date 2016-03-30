#!/bin/bash
cd /home/user/pls

ps -ef | grep -v grep | grep "/home/user/pls/start/startFilter.sh" | wc -l | grep "^2" > /dev/null
if [ $? -eq 0 ]; then
  notify-send -i error 'Filter Open Error' 'Filter screen already open or loading' &
  exit
fi

notify-send -i info 'Loading Filter' 'Please be patient...' &
Rscript --vanilla /home/user/pls/filter.R
pkill startFilter.sh
