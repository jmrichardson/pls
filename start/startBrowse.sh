#!/bin/bash
cd /home/user/pls

ps -ef | grep -v grep | grep "/home/user/pls/start/startBrowse.sh" | wc -l | grep "^2" > /dev/null
if [ $? -eq 0 ]; then
  notify-send -i error 'Browse Notes Open Error' 'Browse notes already running or loading' &
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

notify-send -i info 'Downloading Notes' 'Please be patient.  This could be a minute...' &
Rscript --vanilla /home/user/pls/browse.R
pkill startBrowse.sh
