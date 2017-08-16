#!/bin/bash
set -o errexit

if [ -z "$LOCAL_IP" ];then
	echo "Unknown LOCAL_IP"
	exit 3
fi

function check() {
	for service in firewalld NetworkManager
	do
		cmd="systemctl is-active $service"
		echo $cmd
		eval $cmd && exit 1
		cmd="systemctl is-enabled $service"
		echo $cmd
		eval $cmd && exit 1 || continue
	done
}

check

cat >/etc/yum.repos.d/goodrain.repo <<EOF
[goodrain]
name=goodrain CentOS-\$releasever - for x86_64
baseurl=http://repo.goodrain.com/centos/\$releasever/2017.02/\$basearch
enabled=1
gpgcheck=1
gpgkey=http://repo.goodrain.com/gpg/RPM-GPG-KEY-CentOS-goodrain

[goodrain-noarch]
name=goodrain CentOS-\$releasever - for noarch
baseurl=http://repo.goodrain.com/centos/\$releasever/2017.02/noarch
enabled=1
gpgcheck=1
gpgkey=http://repo.goodrain.com/gpg/RPM-GPG-KEY-CentOS-goodrain
EOF

yum makecache

yum install -y gr-etcd
systemctl is-active etcd || systemctl start etcd
systemctl is-enabled etcd || systemctl enable etcd

yum install -y dc-ctl dc-web

systemctl is-active dc-web || systemctl start dc-web
systemctl is-enabled dc-web || systemctl enable dc-web

yum install -y dc-agent

if [ -f "/var/run/dc-agent.pid" ];then
    pid=`cat /var/run/dc-agent.pid`
    kill -0 $pid || kill -9 $pid
fi

dc-agent -d -s http://$LOCAL_IP:4001

dc-ctl set node $LOCAL_IP --add-identity manage
dc-ctl set node $LOCAL_IP --add-identity compute

dc-ctl import dc_web --address $LOCAL_IP:8088
dc-ctl import etcd --address $LOCAL_IP:4001

dc-ctl init -y

dc-ctl install storage
dc-ctl install network
dc-ctl install manage

dc-ctl install console

dc-ctl install compute --node $LOCAL_IP