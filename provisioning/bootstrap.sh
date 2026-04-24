#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

if [ "$#" -ne 1 ]; then
    echo "Sintaxis: $0 MASTER_HOSTNAME"
    exit -1
fi

MASTER_HOSTNAME=$1
CURRENT_HOST=$(hostname)

#Fix SSHD
if ! grep -q "^Subsystem sftp internal-sftp" /etc/ssh/sshd_config; then
    echo "Subsystem sftp internal-sftp" >> /etc/ssh/sshd_config
    systemctl restart sshd
fi

sed -i '/127.0.1.1.*packer-/d' /etc/hosts 2>/dev/null
sed -i '/127.0.2.1/d' /etc/hosts 2>/dev/null

if [ -b /dev/sdb ]; then
    DISK0=/dev/sdb
elif [ -b /dev/vdb ]; then
    DISK0=/dev/vdb
fi

if [ -b /dev/sdc ]; then
    DISK1=/dev/sdc
elif [ -b /dev/vdc ]; then
    DISK1=/dev/vdc
fi

if [ -b /dev/sdd ]; then
    DISK2=/dev/sdd
elif [ -b /dev/vdd ]; then
    DISK2=/dev/vdd
fi

# Format and mount disks to be used with Hadoop HDFS and Spark
if [ ! -d "/data/disk0" ]; then
    mkdir -p /data/disk0 >& /dev/null
    mkfs.ext4 -F $DISK0
    mount $DISK0 /data/disk0
    chmod 1777 /data/disk0
else
    if ! grep -Fq $DISK0 /proc/mounts ; then
	mount $DISK0 /data/disk0 >& /dev/null
	chmod 1777 /data/disk0
    fi
fi

if [ ! -d "/data/disk1" ]; then
    mkdir -p /data/disk1 >& /dev/null
    mkfs.ext4 -F $DISK1
    mount $DISK1 /data/disk1
    chmod 1777 /data/disk1
else
    if ! grep -Fq $DISK1 /proc/mounts ; then
	mount $DISK1 /data/disk1
	chmod 1777 /data/disk1
    fi
fi

if [ ! -d "/data/disk2" ]; then
    mkdir -p /data/disk2 >& /dev/null
    mkfs.ext4 -F $DISK2
    mount $DISK2 /data/disk2
    chmod 1777 /data/disk2
else
    if ! grep -Fq $DISK2 /proc/mounts ; then
	mount $DISK2 /data/disk2
	chmod 1777 /data/disk2
    fi
fi

if [ ! -d "/data/disk0/hdfs" ]; then
    mkdir /data/disk0/hdfs
fi

if [ ! -d "/data/disk0/spark-tmp" ]; then
    mkdir /data/disk0/spark-tmp
fi

if [ ! -d "/data/disk1/hdfs" ]; then
    mkdir /data/disk1/hdfs
fi

if [ ! -d "/data/disk1/spark-tmp" ]; then
    mkdir /data/disk1/spark-tmp
fi

if [ ! -d "/data/disk2/hdfs" ]; then
    mkdir /data/disk2/hdfs
fi

if [ ! -d "/data/disk2/spark-tmp" ]; then
    mkdir /data/disk2/spark-tmp
fi

chmod 1777 /data/disk0/hdfs
chmod 1777 /data/disk1/hdfs
chmod 1777 /data/disk2/hdfs
chmod 1777 /data/disk0/spark-tmp
chmod 1777 /data/disk1/spark-tmp
chmod 1777 /data/disk2/spark-tmp

if ! grep -Fq $DISK0 /etc/fstab ; then
    echo -e "$DISK0        /data/disk0     ext4    defaults,relatime       0       0" >> /etc/fstab
fi

if ! grep -Fq $DISK1 /etc/fstab ; then
    echo -e "$DISK1        /data/disk1     ext4    defaults,relatime       0       0" >> /etc/fstab
fi

if ! grep -Fq $DISK2 /etc/fstab ; then
    echo -e "$DISK2        /data/disk2     ext4    defaults,relatime       0       0" >> /etc/fstab
fi

systemctl unmask systemd-timesyncd >& /dev/null
systemctl enable systemd-timesyncd.service >& /dev/null
timedatectl set-ntp true
systemctl restart systemd-timesyncd.service >& /dev/null

# Install software
apt-get update
SOFTWARE="dos2unix whois systemd-timesyncd"
echo "==> Installing software packages..."
if ! apt-get install -y -qq $SOFTWARE > /tmp/apt.log 2>&1; then
    echo "Error when installing software, log:"
    cat /tmp/apt.log
    exit 1
fi
echo "==> done"

SSH_PUBLIC_KEY=/vagrant/provisioning/id_rsa.pub
SSH_DIR=/home/vagrant/.ssh
mkdir -p $SSH_DIR
chmod 700 $SSH_DIR

if [ "$CURRENT_HOST" = "$MASTER_HOSTNAME" ]; then
	mkdir -p /etc/ansible
	cp /vagrant/ansible.inventory /etc/ansible/hosts
	cp /vagrant/ansible.cfg /etc/ansible
	chmod 0644 /etc/ansible/hosts
	chmod 0644 /etc/ansible/ansible.cfg

	if [ ! -f $SSH_DIR/id_rsa.pub ]; then
		# Create ssh keys
		echo -e 'y\n' | sudo -u vagrant ssh-keygen -t rsa -f $SSH_DIR/id_rsa -q -N ''
		
		if [ ! -f $SSH_DIR/id_rsa.pub ]; then
			echo "SSH public key could not be created"
			exit -1
		fi
		echo "SSH keys created"
	fi

	if [ ! -f /etc/ssh/ssh_config.d/90-key-checking.conf ]; then
	        cat > /etc/ssh/ssh_config.d/90-key-checking.conf << EOF
Host *
    StrictHostKeyChecking no
EOF
	fi

	chown vagrant:vagrant $SSH_DIR/id_rsa*
	cp $SSH_DIR/id_rsa.pub $SSH_PUBLIC_KEY
else
    sed -i '/127.0.1.1.*-worker/d' /etc/hosts
fi

if [ ! -f $SSH_PUBLIC_KEY ]; then
	echo "SSH public key does not exist"
	exit -1
fi

touch $SSH_DIR/authorized_keys 2>/dev/null
grep -q -f $SSH_PUBLIC_KEY $SSH_DIR/authorized_keys || cat $SSH_PUBLIC_KEY >> $SSH_DIR/authorized_keys
chown vagrant:vagrant $SSH_DIR/authorized_keys
chmod 0600 $SSH_DIR/authorized_keys
