#! /usr/bin/env bash

#
# Script for initialisation image
#
# Copyright (C) 2019 Copter Express Technologies
#
# Author: Andrey Dvornikov <dvornikov-aa@yandex.ru>
#

case "$1" in
   "disable" )
      mv /etc/ld.so.preload /etc/ld.so.preload.bak
      ;;
   "enable" )
      mv /etc/ld.so.preload.bak /etc/ld.so.preload
      ;;
esac
