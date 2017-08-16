#!/bin/bash

# 获取本机dc-agent的ip和id
HOST_UUID=$(dc-ctl get node --self --field id)
HOST_IP=$(dc-ctl get node --self --field ipaddress)

# remove old hosts
sed  -i "/$HOST_IP/d" /etc/hosts /etc/resolv.conf

# 清理数据库
dc-ctl clean db

# 下线节点 （停服务calico、kubelet、docker、etcd, 取消开机启动）
dc-ctl drain node $HOST_UUID

# 检查容器有容器在运行,关掉
dps | grep -v 'PORTS' | awk '{print $1}' | xargs docker rm -f

# 删除数据文件 (/grdata/tenant, /cache/build, /logs等)
dc-ctl clean files

# 设置域名为空
dc-ctl clean domain

# 清除etcd中calico和k8s元数据
dc-ctl clean metadata

# 替换配置文件中本机ip
grep $HOST_IP /etc/goodrain/ -R | awk -F : '{print $1}' | uniq | xargs sed -i "s/$HOST_IP/NEED_IP_MODIFY/"

# etcd 替换 NODES="iZ2zed8w93w30ex1j336ijZ:10.251.193.90"
sed -i "s/$(hostname -s)/NEED_HOSTNAME_MODIFY/" /usr/share/gr-etcd/scripts/start.sh
sed -i "s/$HOST_IP/NEED_IP_MODIFY/" /usr/share/gr-etcd/scripts/start.sh 

# 重置集群配置状态
[ -f /etc/goodrain/.inited ] && rm -f /etc/goodrain/.inited
[ -f /root/ACP_VERSION ] && rm -f /root/ACP_VERSION
[ -f /root/acp_init.log ] && rm -f /root/acp_init.log