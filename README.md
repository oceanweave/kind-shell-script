# kind-shell-script

## 目录结构

``` sh
.
├── cluster-demo-setting
│   ├── 3node-demo.yaml
│   └── ingress-cluster-demo.yaml
└── kind-tool.sh
```

## 简单使用

``` sh
# 进入防止 kind-tool.sh 的目录
$ cd kt-dir/
# 用 alias 给个别名，更便于使用
$ alias kt="./kind-tool.sh"
# 永久生效 此处把 ./kind-tool.sh 换为绝对路径
# zsh  
echo 'alias kt="./kind-tool.sh"' >> ~/.zshrc
source ~/.zshrc
# bash
echo 'alias kt="./kind-tool.sh"' >> ~/.bashrc
source ~/.bashrc



# 创建单节点集群，此种默认采用最新版本镜像
$ kt create single-node-cluster
# 指定 k8s 镜像版本
$ kt create single-node-cluster --image kindest/node:v1.24.5
# 采用 默认版本（目前配置为  kindest/node:v1.24.3 ）——  k8s 1.24.3 版本
$ kt create single-node-cluster --default

# 查看目前配置的多节点集群模板
$ kt cds list
🔍 Listing all available templates:
- 3node-demo
- ingress-cluster-demo

# 创建 3 节点的集群
$ kt create 3-node-cluster --image kindest/node:v1.24.3 --config 3node-demo

# 查看当前所有集群
$ kt list

# 删除集群
$ kt delete 3-node-cluster

# 加载指定镜像到指定集群
# 简化操作，加载到当前集群
$ kt load busybox:latest
# 加载到指定集群
$ kt load busybox:latest 3-node-1.24.3


# 查看帮助信息
$ kt -h
Usage: ./kind-tool.sh [command] [options]
Commands:
  create <cluster-name> [--image <image>] [--config <template>] [--default]  Create a new Kind cluster
    sub-args:
      --image <image>                   Create a cluster using the image you specified
      --config <template>               Template is used to configure the architecture of the cluster (multi node or port exposure)
      --default                         Create a cluster using the default image version (k8s 1.24.3)
  delete <cluster-name>                 Delete the Kind cluster
  export-kubeconfig <cluster-name>      Export Kubeconfig for cluster, Short command(ek)
  load-image <cluster-name> <image>     Load Docker image into Kind cluster, Short command(load)
  status <cluster-name>                 Get cluster status
  list                                  List all existing Kind clusters
  use <cluster-name>                    Switch to the specified Kind cluster
  cluster-demo-setting <subcommand> [options]  Short command(cds for cluster-demo-setting)
    subcommands:
      list                              List all supported templates
      show <template-name>              Show the content of a specific template
  help                                  Display this help message
```



## 脚本

``` sh
#!/bin/bash

# 配置
KUBECONFIG_PATH="./"
WITH_METRICS=false
WITH_INGRESS=false
LOAD_IMAGE=false
DEFAULT_IMAGE="kindest/node:v1.24.3"  # 默认镜像

# 显示勾选或叉
checkmark="✅"
crossmark="❌"

# 配置到 shell 中，为了便捷使用
# echo 'alias kt="./kind-tool.sh"' >> ~/.zshrc
# source ~/.zshrc

# 模板配置 路径获取
SCRIPT_DIR="$(dirname "$0")"
TEMPLATES_DIR="$SCRIPT_DIR/cluster-demo-setting"
DEFAULT_TEMPLATE="ingress-cluster-demo"
# 设置文件夹路径
Cluster_Config_DIR="$SCRIPT_DIR/clusters-kind-config"



# 打印帮助信息
usage() {
  echo "Usage: $0 [command] [options]"
  echo "Commands:"
  echo "  create <cluster-name> [--image <image>] [--config <template>] [--default]  Create a new Kind cluster"
  echo "    sub-args:"
  echo "      --image <image>                   Create a cluster using the image you specified "
  echo "      --config <template>               Template is used to configure the architecture of the cluster (multi node or port exposure)"
  echo "      --default                         Create a cluster using the default image version (k8s 1.24.3)"
  echo "  delete <cluster-name>                 Delete the Kind cluster"
  echo "  export-kubeconfig <cluster-name>      Export Kubeconfig for cluster, Short command(ek)"
  echo "  load-image <cluster-name> <image>     Load Docker image into Kind cluster, Short command(load)"
  echo "  status <cluster-name>                 Get cluster status"
  echo "  list                                  List all existing Kind clusters"
  echo "  use <cluster-name>                    Switch to the specified Kind cluster"
  echo "  cluster-demo-setting <subcommand> [options]  Short command(cds for cluster-demo-setting)"
  echo "    subcommands:"
  echo "      list                              List all supported templates"
  echo "      show <template-name>              Show the content of a specific template"
  echo "  help                                  Display this help message"
  exit 1
}

# 检查是否安装 kind 和 kubectl
command -v kind &>/dev/null || { echo "Kind is not installed!"; exit 1; }
command -v kubectl &>/dev/null || { echo "kubectl is not installed!"; exit 1; }

# 打印命令并执行
run_command() {
  echo "-------- Command Info -------"
  echo "Executing: $1"
  echo "<-------- Command Result ------->"
  eval "$1"
  echo " "
}

# 加载指定模板配置
load_template() {
  TEMPLATE_NAME=$1
  TEMPLATE_FILE="$TEMPLATES_DIR/$TEMPLATE_NAME.yaml"

  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template '$TEMPLATE_NAME' not found!"
    exit 1
  fi

  echo "#Using template '$TEMPLATE_NAME' from $TEMPLATE_FILE..."
  cat "$TEMPLATE_FILE"
  echo
}

# 创建集群
create_cluster() {
  CLUSTER_NAME=$1
  IMAGE=
  TEMPLATE=

  shift # 移除第一个参数（集群名称）
  
  # 解析命令行参数
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --image) IMAGE="$2"; shift 2 ;;
      --config) TEMPLATE="$2"; shift 2 ;;
      --default) IMAGE=$DEFAULT_IMAGE; shift ;;
      *) echo "Unknown parameter: $1"; usage ;;
    esac
  done

  echo "🚀 Creating Kind cluster: $CLUSTER_NAME with image: $IMAGE and template: $TEMPLATE..."

  # 检查文件夹是否存在
  if [ ! -d "$Cluster_Config_DIR" ]; then
    mkdir "$Cluster_Config_DIR"
  fi

  # 加载模板
  if [ -n "$TEMPLATE" ]; then
    # 在 Shell 中，等号两边不能有空格。正确的赋值方式是：
    # 在 Shell 脚本中，使用 export 创建的环境变量是只在脚本运行时有效的，退出脚本后环境变量将不会在当前的终端会话中存在
    export KT_CLUSTER_NAME="$CLUSTER_NAME"
    USER_CLUSTER_FILE="$Cluster_Config_DIR/$CLUSTER_NAME-kind-config.yaml"
    load_template "$TEMPLATE" > "$USER_CLUSTER_FILE"
    # 在 macOS 上，sed -i 需要加空字符串 ''（这是 macOS 上 sed 的要求），而在 Linux 上，直接 sed -i 就可以。
    # 方法2：可以通过 envsubst 来替换配置文件中的环境变量
    # envsubst < 3node-template > 3node-template.tmp：将模板文件内容通过 envsubst 进行替换，并将替换后的内容输出到临时文件 3node-template.tmp 中
    sed -i '' -e "s/\${KT_CLUSTER_NAME}/$KT_CLUSTER_NAME/g" -e "s/\${NODE_IMAGE}/$NODE_IMAGE/g" "$USER_CLUSTER_FILE"
    CONFIG="--config $Cluster_Config_DIR/$CLUSTER_NAME-kind-config.yaml"
  fi

  # 打印并执行创建集群命令
  if [ -n "$CONFIG" ] && [ -n "$IMAGE" ]; then
    run_command "kind create cluster --name \"$CLUSTER_NAME\" --image \"$IMAGE\" $CONFIG"
  elif [ -n "$CONFIG" ]; then
    run_command "kind create cluster --name \"$CLUSTER_NAME\" $CONFIG"
  elif [ -n "$IMAGE" ]; then
    run_command "kind create cluster --name \"$CLUSTER_NAME\" --image \"$IMAGE\""
  else
    run_command "kind create cluster --name \"$CLUSTER_NAME\""
  fi

  # 如果需要安装 metrics-server
  if $WITH_METRICS; then
    echo "📊 Installing metrics-server..."
    run_command "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  fi

  # 如果需要安装 ingress-nginx
  if $WITH_INGRESS; then
    echo "🌐 Installing ingress-nginx..."
    run_command "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml"
  fi

  echo "✅ Cluster created successfully!"
}

# 切换集群
use_cluster() {
  CLUSTER_NAME=$1
  echo "🔄 Switching to Kind cluster: $CLUSTER_NAME..."
  run_command "kubectl config use-context kind-$CLUSTER_NAME"
  echo "✅ Switched to $CLUSTER_NAME."
}

# 导出 kubeconfig 文件
export_kubeconfig() {
  CLUSTER_NAME=$1
  echo "📤 Exporting kubeconfig to $KUBECONFIG_PATH..."

  # 打印并执行导出 kubeconfig 命令
  KUBECONFIG_FILE="./$CLUSTER_NAME-kubeconfig"
  run_command "kind get kubeconfig --name \"$CLUSTER_NAME\" > \"$KUBECONFIG_FILE\""

  echo "✅ Kubeconfig exported!"
}


# 加载 Docker 镜像到 Kind 集群
load_image() {
  CLUSTER_NAME=$1
  IMAGE_TAG=$2
  echo "💾 Loading Docker image '$IMAGE_TAG' into Kind cluster '$CLUSTER_NAME'..."

  # 打印并执行加载镜像命令
  run_command "kind load docker-image \"$IMAGE_TAG\" --name \"$CLUSTER_NAME\""

  echo "✅ Image loaded successfully!"
}


# 健康检查函数
health_check() {
  echo "🧠 Running health check for the cluster..."

  echo -n "🧩 Nodes reachable: "
  run_command "kubectl get nodes &>/dev/null && echo \"$checkmark\" || echo \"$crossmark\""

  echo -n "📈 Metrics-server running: "
  run_command "kubectl get deployment metrics-server -n kube-system &>/dev/null && echo \"$checkmark\" || echo \"$crossmark\""

  echo -n "🌐 Ingress controller running: "
  run_command "kubectl get pods -n ingress-nginx &>/dev/null && echo \"$checkmark\" || echo \"$crossmark\""

  echo -n "🧪 Demo app deployed: "
  run_command "kubectl get deploy demo &>/dev/null && echo \"$checkmark\" || echo \"$crossmark\""

  echo -n "🛰️ Ingress route configured: "
  run_command "kubectl get ingress demo-ingress &>/dev/null && echo \"$checkmark\" || echo \"$crossmark\""
}

# 处理集群模板设置命令
cluster_demo_setting() {
  if [[ "$1" == "list" ]]; then
    echo "🔍 Listing all available templates:"
    for template in "$TEMPLATES_DIR"/*.yaml; do
      echo "- $(basename "$template" .yaml)"
    done
  elif [[ "$1" == "show" ]]; then
    if [[ -z "$2" ]]; then
      echo "Error: Template name is required!"
      exit 1
    fi
    load_template "$2"
  else
    echo "Unknown subcommand: $1"
    usage
  fi
}

# 集群命令执行
case "$1" in
  "create")
    if [ -z "$2" ]; then
      echo "Cluster name is required!"
      usage
    fi
    # ${@:2} 表示从忽略第一个参数，传入其余所有参数
    create_cluster "${@:2}"
    ;;
  "list")
    echo "🔍 Listing all existing Kind clusters..."
    run_command "kind get clusters"
    run_command "kubectl config get-contexts"
    run_command "kubectl config current-context"
    ;;
  "delete")
    if [ -z "$2" ]; then
      echo "Cluster name is required!"
      usage
    fi
    echo "🗑️ Deleting Kind cluster: $2..."
    run_command "kind delete cluster --name \"$2\""
    ;;
  "status")
    if [ -z "$2" ]; then
      echo "Cluster name is required!"
      usage
    fi
    echo "🔍 Checking cluster status..."
    run_command "kind get clusters | grep -q \"$2\" && echo \"$checkmark Cluster exists: $2\" || echo \"$crossmark Cluster does not exist.\""
    ;;
  "use")
    if [ -z "$2" ]; then
      echo "Cluster name is required to switch!"
      usage
    fi
    use_cluster "$2"
    ;;
  "load"|"load-image")
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo "Both cluster name and image tag are required!"
      usage
    fi
    load_image "$2" "$3"
    ;;
  "ek"|"export-kubeconfig")
    if [ -z "$2" ]; then
     echo "Cluster name is required!"
     usage
    fi
    export_kubeconfig "$2"
    ;;
  "health-check")
    health_check
    ;;
  "cds"|"cluster-demo-setting")
    cluster_demo_setting "${@:2}"
    ;;
  "-h"|"--help"|"help")
    usage
    ;;
  *)
    usage
    ;;
esac

```



## 集群模板目录

- 脚本同级目录创建`cluster-demo-setting` 目录
- 添加个简单的集群实例

``` sh
# 添加文件 3node-demo.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

