#!/bin/bash
cd /home/user/pls

ps -ef | grep -v grep | grep "/home/user/pls/start/startConfig.sh" | wc -l | grep "^2" > /dev/null
if [ $? -eq 0 ]; then
  notify-send -i error 'System Configuration Open Error' 'System configuration already running or loading' &
  exit
fi

notify-send -i info 'Loading System Configuration' 'Please be patient...' &
Rscript --vanilla /home/user/pls/config.R
pkill startConfig.sh
