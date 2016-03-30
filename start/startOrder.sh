#!/bin/bash
cd /home/user/pls

echo "Starting order service"
sLog='log/startLog.txt'

echo "Starting script ..." >> $sLog

ps -ef | grep -v grep | grep -v '/bin/sh -c' | grep "/home/user/pls/start/startOrder.sh" | wc -l | grep "^2"
if [ $? -eq 0 ]; then
  echo "Service already running"
  notify-send -i error 'PLS Service Error' 'Service already running' &
  exit
fi


if [ ! -f config/user.rda ]; then
  echo "Configuration error"
  notify-send -i error 'System Configuration Error' 'Please configure system' &
  exit
fi

if [ ! -f config/filter.rda ]; then
  echo "Filter error"
  notify-send -i error 'Filter Error' 'Please create a filter' &
  exit
fi

echo "Connecting to dropbox ..." >> $sLog

curl --connect-timeout 8 -k -s https://dl.dropboxusercontent.com/u/415842/PLS/control.txt > /tmp/control.txt
if [ $? -ne 0 ]; then
  msg='Unable to connect to Internet'
  echo $msg
  notify-send -i error 'PLS Error' "$msg"
  lastTS=`date +"%Y-%m-%d %T.9999 PST"`
  echo "$lastTS|$msg" >> /home/user/pls/log/system.log
  exit
fi
grep "^disable:" /tmp/control.txt > /dev/null
if [ $? -eq 0 ]; then
  echo "Order service disabled"
  msg=`grep "^disable:" /tmp/control.txt | cut -d":" -f2`
  notify-send -i error 'PLS Error' "$msg"
  exit
fi
grep "^info:" /tmp/control.txt > /dev/null
if [ $? -eq 0 ]; then
  msg=`grep "^info:" /tmp/control.txt | cut -d":" -f2`
  notify-send -i info 'PLS Important Message' "$msg"
fi

echo "Starting R Order Script ..." >> $sLog
notify-send -i info 'Starting PLS' 'Open log to see activity' &
/usr/local/bin/Rscript --vanilla /home/user/pls/order.R >> log/order.Rout 2>&1

echo "Finishing R Order Script ..." >> $sLog
