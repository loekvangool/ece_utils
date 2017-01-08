#!/bin/bash                                                                                                                                                              
#
#   Install depedencies for Elastic Cloud Enterprise.
#

. /etc/lsb-release

DATA_DIR=`ls /dev/disk/by-id/google-esdata-?`
if [ ! -L "$DATA_DIR" ]; then
    echo "Create the data directory  /dev/disk/by-id/google-esdata-1 or greater before running this bootstrap script."
    exit 1
fi


sudo apt-get update -y

if [ "$DISTRIB_RELEASE" != "14.04" ]; then
    echo "Unsupported Linux distribution. Please install Ubuntu 14.04 LTS."
    exit
fi


sudo apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual xfsprogs

sudo apt-get upgrade -y


# Install docker.
sudo apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 \
    --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo "File not found. Creating:"
    echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" | sudo \
         tee /etc/apt/sources.list.d/docker.list
fi

sudo apt-get update -y
sudo apt-get install -y  --force-yes docker-engine=1.11.2-0~trusty

if [ ! -f /mnt/data ]; then
    echo "Mount point not found. Formating /mnt/data"
    sudo mkfs.xfs -f $DATA_DIR
    sudo install -d -m 700 /mnt/data
fi

# Add the drive to fstab.
if grep -q "google-esdata" /etc/fstab > /dev/null; then
    echo "A /etc/fstab entry for XFS exists."
else
    echo "A /etc/fstab entry for XFS does not exists. Creating:"
    echo "$DATA_DIR /mnt/data xfs  defaults,pquota,prjquota  0 0"| sudo tee -a /etc/fstab
fi

sudo service docker stop

# Add settings to grub.
if grep -q "cgroup_enable" /etc/default/grub > /dev/null; then
    echo "A grub entry for cgroups is already present."
else
    echo "Updating:"
    sed 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\"/g' /etc/default/grub | sudo tee /tmp/ece_temp_grub
    sudo mv -v /tmp/ece_temp_grub /etc/default/grub
    sudo update-grub
fi

if grep -q "vm.max_map_count" /etc/sysctl.conf > /dev/null; then
        echo "vm.max_map_count is already set correctly."
else
        echo "Updateing vm.max_map_count in /etc/sysctl.conf"
        echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
fi

if grep -q ubuntu /etc/security/limits.conf > /dev/null; then
        echo "Security settings already set for user ubuntu."
else
        echo "Updating security settings in /etc/security/limits.conf"
        cat << LIMITS | sudo tee -a /etc/security/limits.conf
*                soft    nofile         1024000
*                hard    nofile         1024000
*                soft    memlock        unlimited
*                hard    memlock        unlimited
ubuntu           soft    nofile         1024000
ubuntu           hard    nofile         1024000
ubuntu           soft    memlock        unlimited
ubuntu           hard    memlock        unlimited
root             soft    nofile         1024000
root             hard    nofile         1024000
root             soft    memlock        unlimited
LIMITS
fi

sudo mount $DATA_SIR
sudo chown $USER:$USER /mnt/data
sudo install -d -m 700 /mnt/data/docker

if grep -q "xfs" /etc/default/docker > /dev/null; then
        echo "Docker already configured"
else
        echo "DOCKER_OPTS=\"-g /mnt/data/docker -s=devicemapper --storage-opt dm.fs=xfs --bip=172.17.42.1/16\"" | sudo tee -a /etc/default/docker
fi

sudo service docker restart

sudo usermod -aG docker $USER


if [ ! -f /etc/sysctl.d/70-cloudenterprise.conf ]; then
        cat << SETTINGS | sudo tee /etc/sysctl.d/70-cloudenterprise.conf
net.ipv4.tcp_max_syn_backlog=65536
net.core.somaxconn=32768
net.core.netdev_max_backlog=32768
SETTINGS
fi

python -c "for i in range(10000,30000): print '{0}:{0}'.format(i)" | sudo tee /etc/projid > /dev/null

# To seed entropy for the install script token generation. Will be removed with move the /dev/urandom happens.
sudo apt-get install haveged -y

echo "Sytem reboot in 10 seconds"

sleep 10

sudo reboot
