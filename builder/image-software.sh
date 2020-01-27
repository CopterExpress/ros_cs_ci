#! /usr/bin/env bash

#
# Script for install software to the image.
#
# Copyright (C) 2019 Copter Express Technologies
#
# Author: Artem Smirnov <urpylka@gmail.com>
#

set -e # Exit immidiately on non-zero result

echo_stamp() {
  # TEMPLATE: echo_stamp <TEXT> <TYPE>
  # TYPE: SUCCESS, ERROR, INFO

  # More info there https://www.shellhacks.com/ru/bash-colors/

  TEXT="$(date '+[%Y-%m-%d %H:%M:%S]') $1"
  TEXT="\e[1m${TEXT}\e[0m" # BOLD

  case "$2" in
    SUCCESS)
    TEXT="\e[32m${TEXT}\e[0m";; # GREEN
    ERROR)
    TEXT="\e[31m${TEXT}\e[0m";; # RED
    *)
    TEXT="\e[34m${TEXT}\e[0m";; # BLUE
  esac
  echo -e ${TEXT}
}

# https://gist.github.com/letmaik/caa0f6cc4375cbfcc1ff26bd4530c2a3
# https://github.com/travis-ci/travis-build/blob/master/lib/travis/build/templates/header.sh
my_travis_retry() {
  local result=0
  local count=1
  while [ $count -le 3 ]; do
    [ $result -ne 0 ] && {
      echo -e "\n${ANSI_RED}The command \"$@\" failed. Retrying, $count of 3.${ANSI_RESET}\n" >&2
    }
    # ! { } ignores set -e, see https://stackoverflow.com/a/4073372
    ! { "$@"; result=$?; }
    [ $result -eq 0 ] && break
    count=$(($count + 1))
    sleep 1
  done

  [ $count -gt 3 ] && {
    echo -e "\n${ANSI_RED}The command \"$@\" failed 3 times.${ANSI_RESET}\n" >&2
  }

  return $result
}

echo_stamp "Install apt keys & repos"

# TODO: This STDOUT consist 'OK'
curl http://deb.coex.tech/aptly_repo_signing.key 2> /dev/null | apt-key add -
apt-get update \
&& apt-get install --no-install-recommends -y -qq dirmngr > /dev/null \
&& apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

echo "deb http://packages.ros.org/ros/ubuntu stretch main" > /etc/apt/sources.list.d/ros-latest.list
echo "deb http://deb.coex.tech/rpi-ros-kinetic stretch main" > /etc/apt/sources.list.d/rpi-ros-kinetic.list
echo "deb http://deb.coex.tech/clever stretch main" > /etc/apt/sources.list.d/clever.list

echo_stamp "Update apt cache"

# TODO: FIX ERROR: /usr/bin/apt-key: 596: /usr/bin/apt-key: cannot create /dev/null: Permission denied
apt-get update -qq
# && apt upgrade -y

echo_stamp "Software installing"
apt-get install --no-install-recommends -y \
unzip \
zip \
screen \
byobu  \
lsof \
git \
dnsmasq  \
tmux \
vim \
cmake \
ltrace \
python-rosdep \
python-rosinstall-generator \
python-wstool \
python-rosinstall \
build-essential \
pigpio python-pigpio \
i2c-tools \
ntpdate \
python-dev \
libxml2-dev \
libxslt-dev \
python-future \
python-lxml \
mc \
libboost-system-dev \
libboost-program-options-dev \
libboost-thread-dev \
libreadline-dev \
socat \
dnsmasq \
openvpn \
autoconf \
automake \
libtool \
python3-future \
python-monotonic \
libyaml-dev \
&& echo_stamp "Everything was installed!" "SUCCESS" \
|| (echo_stamp "Some packages wasn't installed!" "ERROR"; exit 1)

echo_stamp "Updating kernel"
apt-get install --no-install-recommends -y raspberrypi-kernel

# Deny byobu to check available updates
sed -i "s/updates_available//" /usr/share/byobu/status/status
# sed -i "s/updates_available//" /home/pi/.byobu/status

echo_stamp "Installing pip"
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py
rm get-pip.py
#my_travis_retry pip install --upgrade pip
#my_travis_retry pip3 install --upgrade pip

echo_stamp "Make sure both pip is installed"
pip --version

echo_stamp "Check MAVLink repository status"
cd /home/pi/mavlink && \
git status

echo_stamp "Build pymavlink"
my_travis_retry pip install -r /home/pi/pymavlink/requirements.txt && \
cd /home/pi/pymavlink && \
git status && \
MDEF=/home/pi/mavlink/message_definitions pip2 install . -v \
|| (echo_stamp "Failed to build pymavlink!" "ERROR"; exit 1)

echo_stamp "Build mavlink-router"
cd /home/pi/mavlink-router \
&& git status \
&& mkdir build \
&& ./autogen.sh \
&& ./configure CFLAGS='-g -O2' \
  --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64 \
  --prefix=/usr \
&& make \
&& make install \
&& cd .. \
&& rm -r mavlink-router \
|| (echo_stamp "Failed to build mavlink-router!" "ERROR"; exit 1)

echo_stamp "Build libcyaml"
cd /home/pi/libcyaml \
&& git status \
&& make -j4 \
&& make install \
&& cd .. \
&& rm -r libcyaml \
|| (echo_stamp "Failed to build libcyaml!" "ERROR"; exit 1)

echo_stamp "Build mavlink-fast-switch"
cd /home/pi/mavlink-fast-switch \
&& git status \
&& mkdir build \
&& cd build \
&& cmake -DCMAKE_BUILD_TYPE=Release .. \
&& make -j4 \
&& make install \
|| (echo_stamp "Failed to build mavlink-fast-switch!" "ERROR"; exit 1)

echo_stamp "Add .vimrc"
cat << EOF > /home/pi/.vimrc
set mouse-=a
syntax on
autocmd BufNewFile,BufRead *.launch set syntax=xml
EOF

echo_stamp "Change default keyboard layout to US"
sed -i 's/XKBLAYOUT="gb"/XKBLAYOUT="us"/g' /etc/default/keyboard

echo_stamp "Attempting to kill dirmngr"
gpgconf --kill dirmngr
# dirmngr is only used by apt-key, so we can safely kill it.
# We ignore pkill's exit value as well.
pkill -9 -f dirmngr || true

echo_stamp "Enable services"
systemctl enable mavlink-fast-switch@cs \
&& systemctl enable pigpiod \
|| (echo_stamp "Failed to enable services!" "ERROR"; exit 1)

echo_stamp "End of software installation"
