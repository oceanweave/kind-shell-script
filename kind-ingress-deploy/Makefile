# 本地集群的名称
KUBE_CLUSTER ?= k8s-cluster-ingress
# kind 创建的 k8s 集群版本
K8S_CLUSTER_IMAGE ?= kindest/node:v1.24.3
# 本地集群配置文件的名称
KUBE_CLUSTER_INIT_CONFIGFILE ?= kind-clusters-mutil-config.yaml
# 需要导入 kind 集群的镜像
# IMG_INGRESS ?= gcr.io/k8s-staging-ingress-nginx/controller:v1.3.0-1.24-arm64-v0.1
IMG_INGRESS ?= xiangshan.harbor.io/ingress-nginx/controller:v1.3.0
IMG_HELLOWORLD ?= wouterm/helloworld:latest
# Ingress-github version
# INGRESS_NGNIX_CTL_VERSION ?=v1.6.4
 
.PHONY: create-new-k8s-single
create-new-k8s-single: # create only 1 master node k8s cluster（new version） 
	kind create cluster --name ${KUBE_CLUSTER} --config ./${KUBE_CLUSTER_INIT_CONFIGFILE} 
 
.PHONY: create-new-k8s-option
create-new-k8s-option: # create multiple nodes k8s cluster（new version）and other setting
	kind create cluster --name ${KUBE_CLUSTER} --config ./${KUBE_CLUSTER_INIT_CONFIGFILE} 
 
.PHONY: create-k8s-default  # create only 1 master node k8s cluster 
create-k8s-single: 
	kind create cluster --name ${KUBE_CLUSTER} --image ${K8S_CLUSTER_IMAGE} 
 
.PHONY: create-k8s-option  # create multiple nodes k8s cluster and other setting
create-k8s-option: 
	kind create cluster --name ${KUBE_CLUSTER} --config ./${KUBE_CLUSTER_INIT_CONFIGFILE} --image ${K8S_CLUSTER_IMAGE} 
 
.PHONY: delete-k8s
delete-k8s: ## delete local k8s
	kind delete cluster --name ${KUBE_CLUSTER}
 
.PHONY: install-ingress-github
install-ingress-github: ## install ingress by mainfest.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGNIX_CTL_VERSION}/deploy/static/provider/kind/deploy.yaml
 
.PHONY: kind-load
kind-load: ## load the local image to the kind cluster
	kind load docker-image ${IMG_INGRESS} --name ${KUBE_CLUSTER}
	kind load docker-image ${IMG_HELLOWORLD} --name ${KUBE_CLUSTER}
 
.PHONY: install-ingress
	# 在 Shell 中，命令的返回值（也称为退出状态码）用于指示命令执行的成功或失败。通常情况下，退出状态码为 0 表示成功，非零值表示失败。
	# 成功执行，退出码为 0；不成功执行，退出码为1
	# @if: 这是 Makefile 中的条件语句的开始。@ 符号用于阻止 Make 工具输出这行命令本身，只输出命令的执行结果。
	# @ 作用用于执行 if 命令，而不是直接输出到 shell 
install-ingress: kind-load # 部署 ingress-nginx-controller
	@echo "Checking if ingress-nginx namespace exists..."
	@if ! kubectl get namespace ingress-nginx >/dev/null 2>&1; then \
        	echo "Namespace ingress-nginx does not exist, creating..."; \
        	kubectl create namespace ingress-nginx; \
    	else \
        	echo "Namespace ingress-nginx already exists."; \
    	fi
	kubectl apply -f ./ingress-deploy/
	kubectl get po -n ingress-nginx -o wide
 
.PHONY: uninstall-ingress # 卸载 ingress-nginx-controller
uninstall-ingress: 
	kubectl delete -f ./ingress-deploy/
	kubectl get po -n ingress-nginx
 
.PHONY: deploy-ingress-demo # 创建 Ingress 资源，和 helloword Service 进行测试
deploy-ingress-demo: 
	@if ! kubectl get svc helloworld >/dev/null 2>&1; then \
        	echo "Service HelloWorld does not exist, creating..."; \
        	kubectl apply ./ingress-demo/helloworld.yaml; \
    	else \
        	echo "Service HelloWorld already exists."; \
    	fi
	kubectl apply -f ./ingress-demo/create-ingress-demo.yaml
 
.PHONY: update-ingress-demo # 更新 Ingress 资源
update-ingress-demo: 
	kubectl apply -f ./ingress-demo/create-ingress-demo.yaml
 
.PHONY: delete-ingress-demo # 删除 Ingress 资源
delete-ingress-demo: 
	kubectl delete -f ./ingress-demo/create-ingress-demo.yaml


