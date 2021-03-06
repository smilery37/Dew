#!/usr/bin/env bash

sbin="`dirname "$0"`"
sbin="`cd "$sbin"; pwd`"
. $sbin/conf.sh

export DEW_NICENESS=0
export RUNNER="java -cp $DEW_HOME/dew.assembly/dew.jar"

rotate_log ()
{
    log=$1;
    num=5;
    if [ -n "$2" ]; then
        num=$2
    fi
    if [ -f "$log" ]; then # rotate logs
        while [ $num -gt 1 ]; do
            prev=`expr $num - 1`
            [ -f "$log.$prev" ] && mv "$log.$prev" "$log.$num"
            num=$prev
        done
        mv "$log" "$log.$num";
    fi
}

option=$1
shift
command=$1
shift

export LOG_DIR=$DEW_HOME/logs
mkdir -p "$LOG_DIR"
export DEW_IDENT="$USER"
touch "$LOG_DIR"/.dew_test > /dev/null 2>&1
TEST_LOG_DIR=$?
if [ "${TEST_LOG_DIR}" = "0" ]; then
  rm -f "$LOG_DIR"/.dew_test
else
  chown "$DEW_IDENT" "$LOG_DIR"
fi
log="$LOG_DIR/dew-$DEW_IDENT-$command-$HOSTNAME.out"

export PID_DIR=/tmp
pid="$PID_DIR/dew-$DEW_IDENT-$command.pid"

case $option in

  (start)

    mkdir -p $PID_DIR
    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo $command running as process `cat $pid`.  Stop it first.
        exit 1
      fi
    fi

    rotate_log $log
    echo starting $command, logging to $log
    nohup nice -n $DEW_NICENESS $RUNNER $command $@ >> "$log" 2>&1 < /dev/null &
    newpid=$!
    echo $newpid > $pid
    sleep 2
    # Check if the process has died; in that case we'll tail the log so the user can see
    if ! kill -0 $newpid >/dev/null 2>&1; then
      echo "failed to launch $command:"
      tail -2 "$log" | sed 's/^/  /'
      echo "full log in $log"
    fi
    ;;

  (stop)

    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo stopping $command
        kill `cat $pid`
      else
        echo no $command to stop
      fi
    else
      echo no $command to stop
    fi
    ;;

esac
