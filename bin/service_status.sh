#!/bin/bash


cron="no"
ps -ef | grep -v grep | grep crond > /dev/null
[ $? -eq 0 ] && cron="yes"


crontab -l | grep startOrder > /dev/null
if [ $? -eq 0 -a $cron = "yes" ]; then
  echo "<img>/usr/share/pixmaps/clock_green.png</img>"
  echo "<txt> Service On </txt>"
  echo "<tool> Service is enabled </tool>"
else
  echo "<img>/usr/share/pixmaps/clock_red.png</img>"
  echo "<txt> Service Off </txt>"
  echo "<tool> Service is not enabled </tool>"
fi
