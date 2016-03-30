#!/bin/bash
cd /home/user/pls

ps -ef | grep -v grep | grep "/home/user/pls/start/startLog.sh" | wc -l | grep "^2" >> /tmp/startLog.txt
if [ $? -eq 0 ]; then
  notify-send -i error 'System Log Open Error' 'System Log already running or loading' &
  exit
fi

notify-send -i info 'Loading Log File' 'Please be patient...' &
Rscript --vanilla /home/user/pls/log.R
pkill startLog.sh
