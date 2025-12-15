# Angular K8s Demo

一个简单的Angular应用，配置了GitHub Actions CI/CD和Kubernetes部署。

## 项目结构

```
angular-demo/
├── src/                    # Angular源代码
│   ├── app/               # 应用组件
│   ├── assets/            # 静态资源
│   ├── index.html         # 主HTML文件
│   ├── main.ts            # 应用入口
│   └── styles.css         # 全局样式
├── k8s/                   # Kubernetes配置
│   ├── deployment.yaml    # 部署配置
│   ├── service.yaml       # 服务配置
│   └── ingress.yaml       # Ingress配置
├── .github/workflows/     # GitHub Actions
│   └── deploy.yml         # CI/CD工作流
├── Dockerfile             # Docker镜像构建
├── nginx.conf             # Nginx配置
└── package.json           # 项目依赖
```

## 本地开发

### 安装依赖

```bash
npm install
```

### 启动开发服务器

```bash
npm start
```

访问 http://localhost:4200

### 构建生产版本

```bash
npm run build
```

## Docker构建

### 构建镜像

```bash
docker build -t angular-k8s-demo .
```

### 运行容器

```bash
docker run -p 8080:80 angular-k8s-demo
```

访问 http://localhost:8080

## Kubernetes部署

### 前置条件

- 已配置kubectl
- 有可用的Kubernetes集群

### 部署应用

```bash
# 应用所有配置
kubectl apply -f k8s/

# 或者单独应用
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

### 查看部署状态

```bash
# 查看pods
kubectl get pods

# 查看服务
kubectl get svc

# 查看ingress
kubectl get ingress
```

### 更新部署

```bash
# 更新镜像
kubectl set image deployment/angular-k8s-demo angular-k8s-demo=your-dockerhub-username/angular-k8s-demo:new-tag

# 查看滚动更新状态
kubectl rollout status deployment/angular-k8s-demo
```

## GitHub Actions CI/CD

### 配置步骤

1. 在GitHub仓库中设置以下Secrets：
   - `DOCKER_USERNAME`: Docker Hub用户名
   - `DOCKER_PASSWORD`: Docker Hub密码或访问令牌
   - `KUBECONFIG`: Kubernetes配置文件（base64编码）

2. 修改 `.github/workflows/deploy.yml` 中的镜像名称：
   ```yaml
   env:
     DOCKER_IMAGE: your-dockerhub-username/angular-k8s-demo
   ```

3. 修改 `k8s/deployment.yaml` 中的镜像名称：
   ```yaml
   image: your-dockerhub-username/angular-k8s-demo:latest
   ```

### 获取KUBECONFIG

```bash
# 将kubeconfig编码为base64
cat ~/.kube/config | base64
```

### 工作流程

当代码推送到main分支时：
1. 构建Docker镜像
2. 推送镜像到Docker Hub
3. 更新Kubernetes部署
4. 等待滚动更新完成

## 配置说明

### Kubernetes资源

- **Deployment**: 2个副本，配置了健康检查
- **Service**: LoadBalancer类型，暴露80端口
- **Ingress**: 配置域名访问（需要Nginx Ingress Controller）

### 资源限制

- CPU请求: 100m，限制: 200m
- 内存请求: 64Mi，限制: 128Mi

## 自定义配置

### 修改副本数

编辑 `k8s/deployment.yaml`:
```yaml
spec:
  replicas: 3  # 修改为所需数量
```

### 修改域名

编辑 `k8s/ingress.yaml`:
```yaml
rules:
  - host: your-domain.com  # 修改为你的域名
```

### 修改应用内容

编辑 `src/app/app.component.ts` 来修改应用显示的内容。

## 故障排查

### 查看Pod日志

```bash
kubectl logs -f deployment/angular-k8s-demo
```

### 查看Pod详情

```bash
kubectl describe pod <pod-name>
```

### 查看事件

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 技术栈

- Angular 17
- TypeScript
- Nginx (生产环境)
- Docker
- Kubernetes
- GitHub Actions
