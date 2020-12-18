#!/bin/bash

start() {
  exec /etc/wan-mode/01-start.sh
}

stop() {
  echo "TODO: stop all service"
  echo "stop accel-ppp"
  sudo service accel-ppp stop
  echo "stop aftr"
  sudo killall aftr
  echo "kill dhcp v6"
  sudo kill -9 `cat /var/run/dhcpd6.pid`

}

case $1 in
  start|stop) "$1" ;;
esac

