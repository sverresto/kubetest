sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# copy in the insecure ssh vagrant key, so we can make a master-box
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" >> /home/vagrant/.ssh/authorized_keys

# pin kernel, so we don't have to fiddle with modules and snapshots
dnf install -y 'dnf-command(versionlock)'
dnf versionlock add kernel kernel-modules kernel-core kernel-tools kernel-tools-libs

dnf update -y
dnf install -y emacs-nox lsof iproute-tc wget jq haproxy

ETCD_RELEASE=$(curl -s https://api.github.com/repos/etcd-io/etcd/releases/latest|grep tag_name | cut -d '"' -f 4)
wget https://github.com/etcd-io/etcd/releases/download/${ETCD_RELEASE}/etcd-${ETCD_RELEASE}-linux-amd64.tar.gz
tar xvf etcd-${ETCD_RELEASE}-linux-amd64.tar.gz
cd etcd-${ETCD_RELEASE}-linux-amd64
sudo mv etcd* /usr/local/bin 

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
systemctl enable --now containerd

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo systemctl enable --now kubelet

echo "export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock" >> /root/.bashrc
source /root/.bashrc

# Preseed the images
kubeadm config images pull

cat>/etc/kubernetes/etcdctl-config<<EOF
export PATH=/usr/local/bin:$PATH
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/apiserver-etcd-client.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/apiserver-etcd-client.key
export ETCDCTL_ENDPOINTS=https://10.10.10.10:2379,https://10.10.10.11:2379,https://10.10.10.12:2379
EOF

cat>/etc/hosts<<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

10.10.10.9  haproxy.example.com  haproxy
10.10.10.10 master-0.example.com master-0
10.10.10.11 master-1.example.com master-1
10.10.10.12 master-2.example.com master-2
EOF

mkdir -m 0700 /root/.ssh

cat>/root/.ssh/id_rsa<<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
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
-----END OPENSSH PRIVATE KEY-----
EOF

cat>/root/.ssh/id_rsa.pub<<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC48iJR0Fv2YZosapgCdRJCzO7FZCzVFtXu1sMQXxR4Fv63eQy/ps05xzBMtlUAWN7hRMWyAM4hlEYltCOBUwTswBZQTHNvkzsQ/E6aN/vUeu9+H8kjhe3kExZaKCXjxw3so5pQRRnY01Ipfa6sAI5F3iCT3j63ufwBF1NMNZ26dy0rYmDaqQjiGa7Pd1NEdyj4rwkU/vLKn5sU2iBQUVtLF5qjU1CzTJC+3P1j2Tn2s2rC/T+E/h1s3BDYDDSP5GFevVMHXurVK+iOGYIn0vbewSs/MT+0h53bYqHCpqASPnJTwcIfDojX+geuMq8cu4dnPoau8OJ0J5YXgrrfXCnwF08X0jHPw5Q5eDne0ZBWFLxyKRbDZGS4XCRkZiNiAnMa1sSDXo/hoLbRqitVeUjqAKC7l0arkIOCD7X373pGzlnp9mj8XzmhdfN14RrbYbLEeytYoXRGbg3P7FvPkGg47Ft/nClsXd5TDDFbf5vBrX0f1Y9NVMoQbLa7Dux3ias= root@master-X
EOF

cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

cat>/root/.ssh/config<<EOF
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF

chmod 600 /root/.ssh/*

cat>/etc/NetworkManager/conf.d/90-dns-none.conf<<EOF
[main]
dns=none
EOF

systemctl reload NetworkManager

cat>/etc/resolv.conf<<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

#curl -L https://github.com/projectcalico/calico/releases/download/v3.22.0/calicoctl-linux-amd64 -o /usr/local/bin/kubectl-calico
#cp /usr/local/bin/kubectl-calico /usr/local/bin/calicoctl
#chmod 755  /usr/local/bin/kubectl-calico
#chmod 755  /usr/local/bin/calicoctl

curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}

echo "export PATH=/usr/local/bin:$PATH" >> /root/.bashrc
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bashrc
