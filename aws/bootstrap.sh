#!/bin/bash
#
#    Install dependencies for Elastic Cloud Enterprise
#    AWS Edition - CentOS 7 - ECE version: alpha4
#    Based on https://www.elastic.co/guide/en/cloud-enterprise/current/ece-configuring.html

sudo yum makecache fast && sudo yum update -y
sudo sysctl -w vm.max_map_count=262144
sudo yum install nano -y
sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org;
sudo rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm;
sudo yum --enablerepo=elrepo-kernel install kernel-ml -y;
sudo awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg;
sudo grub2-set-default 0;
sudo grub2-mkconfig -o /boot/grub2/grub.cfg;
#echo "Rebooting in 10 seconds"
#sleep 10
#sudo reboot

sudo file -s /dev/xvdb
sudo mkfs.xfs /dev/xvdb
sudo install -d -m 700 /mnt/data
echo | sudo tee -a /etc/fstab
echo "/dev/xvdb     /mnt/data/   xfs     defaults,pquota,prjquota  0 0" | sudo tee -a /etc/fstab
sudo mount -a
sudo mkdir -p /mnt/data/elastic
sudo chown -R centos:centos /mnt/data/

sudo yum remove docker-engine -y && sudo yum install -y yum-utils;
sudo yum-config-manager --add-repo https://docs.docker.com/engine/installation/linux/repo_files/centos/docker.repo;
sudo yum makecache fast && sudo yum -y install docker-engine-1.11.2;
sudo service docker stop; sudo service docker start
sudo docker run hello-world

sudo systemctl stop iptables

# Step 1
sudo systemctl stop docker

# Step 2: Add settings to grub.
if grep -q "cgroup_enable" /etc/default/grub > /dev/null; then
    echo "A grub entry for cgroups is already present."
else
    echo "Updating:"
    sed 's/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1 /g' /etc/default/grub | sudo tee /tmp/ece_temp_grub
    sudo mv -v /tmp/ece_temp_grub /etc/default/grub
    sudo grub2-mkconfig -o "$(readlink /etc/grub2.conf)"
fi

#Step 3
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Step 5
echo "" | sudo tee -a /etc/security/limits.conf
echo "*                soft    nofile         1024000" | sudo tee -a /etc/security/limits.conf
echo "*                hard    nofile         1024000" | sudo tee -a /etc/security/limits.conf
echo "*                soft    memlock        unlimited" | sudo tee -a /etc/security/limits.conf
echo "*                hard    memlock        unlimited" | sudo tee -a /etc/security/limits.conf
echo "centos           soft    nofile         1024000" | sudo tee -a /etc/security/limits.conf
echo "centos           hard    nofile         1024000" | sudo tee -a /etc/security/limits.conf
echo "centos           soft    memlock        unlimited" | sudo tee -a /etc/security/limits.conf
echo "centos           hard    memlock        unlimited" | sudo tee -a /etc/security/limits.conf
echo "root             soft    nofile         1024000" | sudo tee -a /etc/security/limits.conf
echo "root             hard    nofile         1024000" | sudo tee -a /etc/security/limits.conf
echo "root             soft    memlock        unlimited" | sudo tee -a /etc/security/limits.conf

# Step 8
sudo install -d -m 700 /mnt/data/docker

# Step 9-11
sudo mkdir -p /etc/systemd/system/docker.service.d/
echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/docker.conf
echo "ExecStart=" | sudo tee -a /etc/systemd/system/docker.service.d/docker.conf
echo "ExecStart=/usr/bin/docker daemon -H fd:// -g /mnt/data/docker -s devicemapper --storage-opt dm.fs=xfs" | sudo tee -a /etc/systemd/system/docker.service.d/docker.conf
sudo systemctl daemon-reload; sudo systemctl restart docker

# Step 12
sudo systemctl enable docker

# Step 13
sudo usermod -aG docker $USER

# Step 14
cat << SETTINGS | sudo tee /etc/sysctl.d/70-cloudenterprise.conf
net.ipv4.tcp_max_syn_backlog=65536
net.core.somaxconn=32768
net.core.netdev_max_backlog=32768
SETTINGS

# Step 15
python -c "for i in range(10000,30000): print '{0}:{0}'.format(i)" | sudo tee /etc/projid > /dev/null

# Step 16
echo "Rebooting in 10 seconds"
sleep 10
sudo reboot
