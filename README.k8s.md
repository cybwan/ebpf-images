

# K8S 集群安装

### 1.1 master

```bash
#所有节点
sudo apt install -y git make
git clone https://github.com/cybwan/osm-edge-scripts.git
cd osm-edge-scripts
make init-k8s-node
#k8s master节点
make init-k8s-node-master
#k8s worker1节点
make init-k8s-node-worker1
#k8s worker2节点
make init-k8s-node-worker2
#所有节点
make init-k8s-node-local-registry
#k8s master节点
#make init-k8s-node-start-master
make init-k8s-node-start-master-local-registry
#k8s worker1节点
make init-k8s-node-join-worker
#k8s worker2节点
make init-k8s-node-join-worker

make osm-ebpf-up

make osm-ebpf-demo-deploy
make osm-ebpf-demo-affinity

make osm-ebpf-demo-curl-helloworld
make osm-ebpf-demo-curl-helloworld-v1

make osm-ebpf-demo-curl-helloworld-v2

kubeadm config images list
kubeadm config images pull
crictl pull docker.io/calico/cni:v3.25.0
crictl images

# 生成默认配置，便于修改
kubeadm config print init-defaults > kubeadm.yaml
sed -i "s/advertiseAddress: 1.2.3.4/advertiseAddress: 192.168.226.50/g" kubeadm.yaml
sed -i "s/name: node/name: ${HOSTNAME}/g" kubeadm.yaml
sed -i "s/kubernetesVersion: 1.24.0/kubernetesVersion: 1.24.10/g" kubeadm.yaml
sed -i "s/imageRepository: registry.k8s.io/imageRepository: local.registry/g" kubeadm.yaml
sed -i "/kubernetesVersion: 1.24.10/acontrolPlaneEndpoint: '192.168.226.50:6443'" kubeadm.yaml
sed -i "/dnsDomain: cluster.local/a\ \ podSubnet: 10.244.0.0/16" kubeadm.yaml
cat >> kubeadm.yaml <<EOF
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF

kubeadm init \
--config kubeadm.yaml \
--ignore-preflight-errors=SystemVerification \
--upload-certs

#sudo kubeadm init --control-plane-endpoint=192.168.226.50

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl cluster-info
kubectl get nodes

kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl taint nodes --all node.kubernetes.io/not-ready:NoSchedule-

curl https://projectcalico.docs.tigera.io/archive/v3.25/manifests/calico.yaml -O
sed -i 's#docker.io#local.registry#g' calico.yaml
kubectl apply -f calico.yaml


wget https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
kubectl apply -f weave-daemonset-k8s.yaml

wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl apply -f kube-flannel.yml

[ ! -f /opt/cni-plugins-linux-amd64-v1.2.0.tgz ] && curl -L https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz -o /opt/cni-plugins-linux-amd64-v1.2.0.tgz
[ ! -d /opt/cni/bin ] && mkdir -p /opt/cni/bin 
[ ! -f /opt/cni/bin/loopback ] && tar zxf /opt/cni-plugins-linux-amd64-v1.2.0.tgz -C /opt/cni/bin

TOKEN=`kubeadm token list | grep default | awk -F" " '{print $1}' |head -n 1`
CAHASH=`openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex |  awk -F" " '{print $2}'`
echo kubeadm join 192.168.226.50:6443 --token ${TOKEN}  --discovery-token-ca-cert-hash sha256:${CAHASH}

kubectl get pods -n kube-system -o wide

kubeadm reset -f
rm -rf ~/.kube
rm -rf /etc/cni
rm -rf /opt/cni
rm -rf /var/lib/etcd
rm -rf /var/etcd
systemctl reboot
systemctl poweroff

apt install -y git cmake make gcc python3 libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf
git clone -b v5.4 https://github.com/torvalds/linux.git --depth 1
cd linux/tools/bpf/bpftool
make
make install

https://www.digitalocean.com/community/tutorials/how-to-set-up-a-private-docker-registry-on-ubuntu-22-04
https://blog.51cto.com/belbert/5872146
https://huaweicloud.csdn.net/633111d5d3efff3090b5121b.html
http://www.liangxiaolei.fun/2021/07/23/docker-buildx%E6%9E%84%E5%BB%BA%E5%A4%9A%E6%9E%B6%E6%9E%84%E6%94%AF%E6%8C%81%E9%95%9C%E5%83%8F/
https://github.com/docker/buildx/issues/80


http://arthurchiao.art/blog/birth-of-sk-lookup-bpf-zh/ *****
http://chenlingpeng.github.io/2020/01/19/ebpf-sockhash-debug/  *****
```

