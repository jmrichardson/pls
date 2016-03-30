#!/bin/bash
cd /home/user/pls

ps -ef | grep -v grep | grep "/home/user/pls/start/startCron.sh" | wc -l | grep "^2" > /dev/null
if [ $? -eq 0 ]; then
  notify-send -i error 'Scheduler Open Error' 'Scheduler already running or loading' &
  exit
fi

if [ ! -f config/user.rda ]; then
  notify-send -i error 'System Configuration Error' 'Please configure system' &
  exit
fi

if [ ! -f config/filter.rda ]; then
  notify-send -i error 'Filter Error' 'Please create a filter' &
  exit
fi

notify-send -t 5000 -i info 'Loading Scheduler' 'Please be patient...' &
Rscript --vanilla /home/user/pls/cron.R
pkill startCron.sh
