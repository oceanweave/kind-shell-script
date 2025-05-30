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
  echo "  load-image <image> <cluster-name>     Load Docker image into Kind cluster, Short command(load)"
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
  #   遇到任何返回非 0 的命令时立即退出
  # 一旦脚本中的某个命令返回非零（即执行失败），整个脚本就会立即终止执行。
  set -e

  IMAGE_TAG="$1"
  CLUSTER_NAME="$2"

  if [ -z "$IMAGE_TAG" ]; then
    echo "❌ 请提供镜像名，例如: kt load my-image:latest"
    exit 1
  fi

  # 如果未传入集群名，则自动获取当前上下文的 kind 集群名
  if [ -z "$CLUSTER_NAME" ]; then
    CONTEXT=$(kubectl config current-context)
    if [[ "$CONTEXT" == kind-* ]]; then
      # bash 字符串操作，具体来说是 删除前缀（Prefix Removal）
      CLUSTER_NAME="${CONTEXT#kind-}"
      echo "📌 未指定集群名，默认使用当前上下文集群: $CLUSTER_NAME"
    else
      echo "❌ 当前上下文不是 kind 集群，请指定集群名"
      exit 1
    fi
  fi
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
    if [ -z "$2" ] ; then
      echo "Image tag are required!"
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
