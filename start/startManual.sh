#!/bin/bash
cd /home/user/pls

ps -ef | grep -v grep | grep -v '/bin/sh -c' | grep "/home/user/pls/start/startManual.sh" | wc -l | grep "^2" > /dev/null
if [ $? -eq 0 ]; then
  notify-send -i error 'PLS Service Error' 'Service already running' &
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

if [ -z $1 ]; then
  zenity --question --text='Running the service manually will immediately download the most recently listed notes (without list detection), filter and potentially submit an order based on your user configuration.  Are you sure you want to run the service?' --title="Run Service?"
  if [ $? -ne 0 ]; then
    exit
  fi
fi

curl --connect-timeout 8 -k -s https://dl.dropboxusercontent.com/u/415842/PLS/control.txt > /tmp/control.txt
if [ $? -ne 0 ]; then
  msg='Unable to connect to Internet.'
  echo $msg
  notify-send -i error 'PLS Error' "$msg"
  lastTS=`date +"%Y-%m-%d %T.9999 PST"`
  echo "$lastTS|$msg" >> /home/user/pls/log/system.log
  exit
fi
grep "^disable:" /tmp/control.txt > /dev/null
if [ $? -eq 0 ]; then
  msg=`grep "^disable:" /tmp/control.txt | cut -d":" -f2`
  notify-send -i error 'PLS Error' "$msg"
  exit
fi
grep "^info:" /tmp/control.txt > /dev/null
if [ $? -eq 0 ]; then
  msg=`grep "^info:" /tmp/control.txt | cut -d":" -f2`
  notify-send -i info 'PLS Important Message' "$msg"
fi
notify-send -i info 'Starting PLS' 'Open log to see activity' &
/usr/local/bin/Rscript --vanilla /home/user/pls/order.R nolist > log/order.Rout 2>&1
pkill startManual.sh
