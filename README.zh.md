

# OSM Edge eBPF 测试

## 1.编译环境初始化

```bash
sudo apt -y update
sudo apt -y install git cmake make gcc python3 libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf
sudo apt -y install libelf-dev make sudo clang iproute2 ethtool

git clone -b v5.4 https://github.com/torvalds/linux.git --depth 1
cd linux/tools/bpf/bpftool
make
make install
cd ~

sudo add-apt-repository -y ppa:cappelikan/ppa
sudo apt -y update
sudo apt -y install mainline
KERNEL=$(mainline --list | grep ^5.19. | head -n 1)
sudo mainline --install ${KERNEL}
sudo apt -y --fix-broken install
sudo systemctl reboot

mainline --yes --uninstall-old
sudo mainline --check

#sudo apt -y --fix-broken install
#sudo add-apt-repository --remove ppa:cappelikan/ppa
#sudo apt remove mainline

git clone https://github.com/merbridge/merbridge.git
cd merbridge

export MESH_MODE=istio
export DEBUG=1
export USE_RECONNECT=1
make load
make attach
make -k clean


ip r delete 0.0.0.0/0
ip r add 0.0.0.0/0 via 192.168.127.101
```

## 2.K8S 集群安装

```
#所有节点
sudo apt install -y git make
git clone https://github.com/cybwan/osm-edge-scripts.git
cd osm-edge-scripts
make init-k8s-node
#k8s master节点
make init-k8s-node-master
#k8s node1节点
make init-k8s-node-node1
#k8s node2节点
make init-k8s-node-node2
#所有节点
make init-k8s-node-local-registry
#k8s master节点
make init-k8s-node-start-master-local-registry
#k8s node1节点
make init-k8s-node-join-node
#k8s node2节点
make init-k8s-node-join-node

#卸载
make init-k8s-node-stop
systemctl poweroff
```

## 3.测试

### 3.1 安装 osm-edge

```bash
export osm_namespace=osm-system 
export osm_mesh_name=osm 

osm install \
    --mesh-name "$osm_mesh_name" \
    --osm-namespace "$osm_namespace" \
    --set=osm.certificateProvider.kind=tresor \
    --set=osm.image.registry=local.registry/flomesh \
    --set=osm.image.tag=latest \
    --set=osm.image.pullPolicy=Always \
    --set=osm.enablePermissiveTrafficPolicy=true \
    --set=osm.sidecarLogLevel=debug \
    --set=osm.controllerLogLevel=warn \
    --set=osm.trafficInterceptionMode=ebpf \
    --set=osm.osmInterceptor.debug=true \
    --timeout=900s
```

### 3.2 部署业务 POD

```bash
#模拟业务服务
kubectl create namespace ebpf
osm namespace add ebpf
kubectl apply -n ebpf -f https://raw.githubusercontent.com/cybwan/osm-edge-start-demo/main/demo/interceptor/curl.yaml
kubectl apply -n ebpf -f https://raw.githubusercontent.com/cybwan/osm-edge-start-demo/main/demo/interceptor/pipy-ok.yaml

#让 Pod 分布到不同的 node 上
kubectl patch deployments pipy-ok-v1 -n ebpf -p '{"spec":{"template":{"spec":{"nodeName":"node1"}}}}'
kubectl patch deployments pipy-ok-v2 -n ebpf -p '{"spec":{"template":{"spec":{"nodeName":"node2"}}}}'

#等待依赖的 POD 正常启动
kubectl wait --for=condition=ready pod -n ebpf -l app=curl --timeout=180s
kubectl wait --for=condition=ready pod -n ebpf -l app=pipy-ok -l version=v1 --timeout=180s
kubectl wait --for=condition=ready pod -n ebpf -l app=pipy-ok -l version=v2 --timeout=180s
```

### 3.3 测试指令

```bash
curl_client="$(kubectl get pod -n ebpf -l app=curl -o jsonpath='{.items[0].metadata.name}')"
kubectl exec ${curl_client} -n ebpf -c curl -- curl -s pipy-ok:8080
```

#### 
