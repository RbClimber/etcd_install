#!/bin/bash

echo -n "请输入要配置etcd集群服务的服务器数量（须为奇数，不能为偶数）："
read etcd_num

res=`expr $etcd_num % 2`

while [ "$res" = "0" ]
do
	read -p "ETCD服务器集群数量须为奇数，请重新输入：" etcd_num
	res=`expr $etcd_num % 2`
done

for i in `seq $etcd_num`
do
read -p "请输入etcd$i的ip地址：" etcd_ip
etcd_[$i]=$etcd_ip
done



echo -n 'ETCD_INITIAL_CLUSTER="' > ${PWD}/ETCD_INITIAL_CLUSTER
for i in `seq $etcd_num`
do
echo -n "ETCD$i=http://${etcd_[$i]}:2380," >> ${PWD}/ETCD_INITIAL_CLUSTER
done
sed -i 's/,$//' ${PWD}/ETCD_INITIAL_CLUSTER
echo -n '"' >> ${PWD}/ETCD_INITIAL_CLUSTER

for i in `seq $etcd_num`
do 
scp ${PWD}/etcdstart.sh ${etcd_[$i]}:$HOME/
scp ${PWD}/etcd-3.2.9-3.el7.x86_64.rpm ${etcd_[$i]}:$HOME/
scp ${PWD}/ETCD_INITIAL_CLUSTER ${etcd_[$i]}:$HOME/
done

for i in `seq $etcd_num`
do
pdsh -w ssh:${etcd_[$i]} "systemctl stop firewalld.service;
systemctl disable firewalld.service;
sed -i 's/enforcing/disabled/' /etc/selinux/config;
sed -i 's/permissive/disabled/' /etc/selinux/config;
yes|cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"
done

for i in `seq $etcd_num`
do
pdsh -w ssh:${etcd_[$i]} "rpm -ivh etcd-3.2.9-3.el7.x86_64.rpm"
done

for i in `seq $etcd_num`
do
pdsh -w ssh:${etcd_[$i]} "sed -i 's/ETCD/#ETCD/g' /etc/etcd/etcd.conf;
echo -n 'ETCD_INITIAL_CLUSTER_STATE=' >> /etc/etcd/etcd.conf;
echo -n '\"' >> /etc/etcd/etcd.conf;
echo -n 'new' >> /etc/etcd/etcd.conf;
echo '\"' >> /etc/etcd/etcd.conf;
echo -n 'ETCD_INITIAL_CLUSTER_TOKEN=' >> /etc/etcd/etcd.conf;
echo -n '\"' >> /etc/etcd/etcd.conf;
echo -n 'etcd-cluster_jp' >> /etc/etcd/etcd.conf;
echo '\"' >> /etc/etcd/etcd.conf;
echo -n 'ETCD_NAME=' >> /etc/etcd/etcd.conf;
echo -n '\"' >> /etc/etcd/etcd.conf;
echo -n "ETCD$i" >> /etc/etcd/etcd.conf;
echo '\"' >>  /etc/etcd/etcd.conf;
echo -n 'ETCD_DATA_DIR=' >> /etc/etcd/etcd.conf;
echo -n '\"' >> /etc/etcd/etcd.conf;
echo -n "/var/lib/etcd/ETCD$i.etcd" >> /etc/etcd/etcd.conf;
echo '\"' >> /etc/etcd/etcd.conf;
echo -n 'ETCD_LISTEN_PEER_URLS=' >> /etc/etcd/etcd.conf;
echo -n '\"' >> /etc/etcd/etcd.conf;
echo -n "http://${etcd_[$i]}:2380" >> /etc/etcd/etcd.conf;
echo '\"' >> /etc/etcd/etcd.conf;
echo -n 'ETCD_LISTEN_CLIENT_URLS=' >> /etc/etcd/etcd.conf;
echo -n '\"' >>/etc/etcd/etcd.conf
echo -n "http://${etcd_[$i]}:2379," >> /etc/etcd/etcd.conf;
echo -n "http://127.0.0.1:2379" >> /etc/etcd/etcd.conf
echo '\"' >> /etc/etcd/etcd.conf;
echo -n 'ETCD_ADVERTISE_CLIENT_URLS=' >> /etc/etcd/etcd.conf;
echo -n '\"' >> /etc/etcd/etcd.conf;
echo -n "http://${etcd_[$i]}:2379" >> /etc/etcd/etcd.conf;
echo '\"' >> /etc/etcd/etcd.conf;
echo -n 'ETCD_INITIAL_ADVERTISE_PEER_URLS=' >> /etc/etcd/etcd.conf;
echo -n '\"' >> /etc/etcd/etcd.conf;
echo -n "http://${etcd_[$i]}:2380" >> /etc/etcd/etcd.conf;
echo '\"' >> /etc/etcd/etcd.conf;
cat ETCD_INITIAL_CLUSTER >>  /etc/etcd/etcd.conf;
"
done

for i in `seq $etcd_num`
do
pdsh -w ssh:${etcd_[$i]} "
echo 'systemctl start etcd.service' >> $HOME/etcdstart.sh;
yes|cp $HOME/etcdstart.sh /etc/rc.d/init.d/;cd /etc/rc.d/init.d/;
cd /etc/rc.d/init.d/;
chmod +x etcdstart.sh;
chkconfig --add etcdstart.sh;
systemctl daemon-reload;
systemctl enable etcd.service;
systemctl start etcd.service"
done

rm -f ${PWD}/ETCD_INITIAL_CLUSTER
