#!/bin/bash

id -u centos &>/dev/null || sudo useradd centos; PASS=`openssl rand -base64 8`; echo $PASS | passwd --stdin centos; echo 'centos  ALL=(ALL:ALL) ALL' >> /etc/sudoers; echo "Write down centos password: ${PASS}"; PASS=; sleep 3; cd /home/centos/; su centos;
