#!/bin/bash

PID=`ps -ef | grep -v grep | grep order.R | awk '{print $2}'`
if [ ! -z "$PID" ]; then
  kill $PID
fi
