# setup a "HA" kubernetes with vagrant

## Odd stuff:

- A little while after installing cilium, vagrant lost ssh connection
to the boxes. ssh -l root 10.10.10.X and passowrd vagrant works...
- Resolving dns stoped working, turn off dns in NWmanager...

## Create base image

```bash
vagrant up master-0
vagrant ssh

sudo sh /vagrant/deps.sh
exit

ls ~/VirtualBox VMs/
vagrant package --base kubetest_master-0_XXXXXXXXXXXX_XXXXXX

vagrant destroy -f
vagrant box remove package.box
vagrant box add package.box  --name package.box
```

replace almalinux/8 with package.box in Vagrantfile

```bash
vagrant up
```

## on haproxy

```bash
sudo cp -f /vagrant/haproxy.cnf /etc/haproxy/
sudo systemctl enable --now haproxy
exit
```

## on master-0

```bash
sudo /vagrant/cilium.sh
kubeadm init --apiserver-advertise-address=10.10.10.10 --pod-network-cidr=10.32.0.0/16 --control-plane-endpoint "haproxy.example.com:6443" --upload-certs

cilium init

[...]

cilium status
```

## On the other masters

Add --apiserver-advertise-address since vagrant is messing with default route

```bash
kubeadm join ..... --apiserver-advertise-address 10.10.10.11
```

cilium will be in a baaad mode for a while after adding a new master,
but should recover within a minute.

```bash
[root@master-0 bin]# cilium status
    /¯¯\
 /¯¯\__/¯¯\    Cilium:         2 errors
 \__/¯¯\__/    Operator:       OK
 /¯¯\__/¯¯\    Hubble:         disabled
 \__/¯¯\__/    ClusterMesh:    disabled
    \__/

DaemonSet         cilium             Desired: 3, Ready: 2/3, Available: 2/3, Unavailable: 1/3
Deployment        cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
Containers:       cilium             Running: 3
                  cilium-operator    Running: 1
Cluster Pods:     2/2 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.11.1@sha256:251ff274acf22fd2067b29a31e9fda94253d2961c061577203621583d7e85bd2: 3
                  cilium-operator    quay.io/cilium/operator-generic:v1.11.1@sha256:977240a4783c7be821e215ead515da3093a10f4a7baea9f803511a2c2b44a235: 1
Errors:           cilium             cilium          1 pods of DaemonSet cilium are not ready
                  cilium             cilium-2r8vr    controller ipcache-inject-labels is failing since 4s (4x): failed to inject labels into ipcache: local identity allocator uninitialized

[root@master-0 bin]# cilium status
    /¯¯\
 /¯¯\__/¯¯\    Cilium:         OK
 \__/¯¯\__/    Operator:       OK
 /¯¯\__/¯¯\    Hubble:         disabled
 \__/¯¯\__/    ClusterMesh:    disabled
    \__/

DaemonSet         cilium             Desired: 3, Ready: 3/3, Available: 3/3
Deployment        cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
Containers:       cilium             Running: 3
                  cilium-operator    Running: 1
Cluster Pods:     2/2 managed by Cilium
Image versions    cilium             quay.io/cilium/cilium:v1.11.1@sha256:251ff274acf22fd2067b29a31e9fda94253d2961c061577203621583d7e85bd2: 3
                  cilium-operator    quay.io/cilium/operator-generic:v1.11.1@sha256:977240a4783c7be821e215ead515da3093a10f4a7baea9f803511a2c2b44a235: 1
```

## scedule on master nodes

```bash
kubectl taint node --all node-role.kubernetes.io/master:NoSchedule-
```

## 

