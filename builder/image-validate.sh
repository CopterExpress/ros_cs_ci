#!/usr/bin/env bash

#
# Validate built image using tests
#
# Copyright (C) 2019 Copter Express Technologies
#
# Author: Oleg Kalachev <okalachev@gmail.com>
#

set -ex

echo "Run image tests"

export ROS_DISTRO='melodic'
export ROS_IP='127.0.0.1'
source /opt/ros/melodic/setup.bash
source /home/pi/ros_cs_ws/devel/setup.bash

#cd /home/pi/ros_cs_ws/src/ros_cs/builder/test/
#./tests.sh
#./tests.py
