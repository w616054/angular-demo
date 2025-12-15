# Angular RealWorld 示例前端（DOKS + DOCR）落地方案

目标：复用现成的 `gothinkster/angular-realworld-example-app`，用 Docker 容器化，部署到 DigitalOcean Kubernetes（DOKS），镜像放在 DigitalOcean Container Registry（DOCR），通过 GitHub Actions 自动构建与部署，Ingress + cert-manager 自动签发 TLS，全流程使用 pnpm。

## 一次性准备（本地/DO）
- Fork `gothinkster/angular-realworld-example-app` 到个人 GitHub。
- 本地验证：`pnpm install --frozen-lockfile && pnpm run build -- --configuration production`。
- 在 DO 创建 DOCR：`doctl registry create <reg>`，记下 `registry.digitalocean.com/<reg>`。
- 创建 DOKS 集群；安装 Nginx Ingress（DO 市场一键或 Helm）；安装 cert-manager（Jetstack Helm + CRDs）。
- 域名解析：为 `fe.example.com` 添加 A 记录指向 Ingress 的 LB IP。
- 创建镜像拉取密钥（集群内）：  
  `kubectl create secret docker-registry do-regcred --docker-server=registry.digitalocean.com/<reg> --docker-username=doadmin --docker-password=<token> -n default`
- 导出 kubeconfig 并 base64：`doctl kubernetes cluster kubeconfig show <cluster> | base64`.

## 代码库需要新增/修改的文件
- `Dockerfile`（项目根，使用 pnpm + corepack）  

- `k8s/deployment.yaml`
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: frontend
    labels: { app: frontend }
  spec:
    replicas: 2
    selector:
      matchLabels: { app: frontend }
    template:
      metadata:
        labels: { app: frontend }
      spec:
        containers:
          - name: frontend
            image: DOCR_REGISTRY/REPO:TAG
            imagePullPolicy: Always
            ports: [{ containerPort: 80 }]
            resources:
              requests: { cpu: "100m", memory: "128Mi" }
              limits: { cpu: "500m", memory: "256Mi" }
        imagePullSecrets:
          - name: do-regcred
  ```

- `k8s/service.yaml`
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: frontend
  spec:
    type: ClusterIP
    selector: { app: frontend }
    ports:
      - port: 80
        targetPort: 80
  ```

- `k8s/ingress.yaml`
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: frontend
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: letsencrypt-prod
  spec:
    tls:
      - hosts: [ fe.example.com ]
        secretName: frontend-tls
    rules:
      - host: fe.example.com
        http:
          paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: frontend
                  port:
                    number: 80
  ```

- `k8s/cluster-issuer.yaml`
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-prod
  spec:
    acme:
      email: you@example.com
      server: https://acme-v02.api.letsencrypt.org/directory
      privateKeySecretRef:
        name: letsencrypt-prod
      solvers:
        - http01:
            ingress:
              class: nginx
  ```

- GitHub Actions：`.github/workflows/deploy.yml`
  ```yaml
  name: Build and Deploy

  on:
    push:
      branches: [ main ]

  env:
    DO_REGISTRY: registry.digitalocean.com/<reg>
    IMAGE_NAME: frontend

  jobs:
    build-and-deploy:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4

        - uses: actions/setup-node@v4
          with:
            node-version: 18
            cache: pnpm

        - name: Enable corepack
          run: corepack enable

        - name: Install deps
          run: pnpm install --frozen-lockfile

        - name: Build Angular
          run: pnpm run build -- --configuration production

        - name: Build and push image
          uses: docker/build-push-action@v5
          with:
            context: .
            file: ./Dockerfile
            push: true
            tags: ${{ env.DO_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          env:
            DOCKER_BUILDKIT: 1
            DOCKER_CLI_EXPERIMENTAL: enabled
            REGISTRY_USERNAME: ${{ secrets.DOCR_USERNAME }}
            REGISTRY_PASSWORD: ${{ secrets.DOCR_TOKEN }}

        - name: Write kubeconfig
          run: |
            mkdir -p $HOME/.kube
            echo "${KUBECONFIG_CONTENTS}" > $HOME/.kube/config
          env:
            KUBECONFIG_CONTENTS: ${{ secrets.KUBECONFIG_BASE64 }}

        - name: Set image tag in manifests
          run: |
            TAG="${{ github.sha }}"
            REG="${{ env.DO_REGISTRY }}"
            find k8s -name '*.yaml' -print -exec sed -i "s|DOCR_REGISTRY/REPO:TAG|${REG}/frontend:${TAG}|g" {} +

        - name: Deploy
          uses: azure/k8s-deploy@v5
          with:
            namespace: default
            manifests: |
              k8s/cluster-issuer.yaml
              k8s/deployment.yaml
              k8s/service.yaml
              k8s/ingress.yaml
            images: |
              ${{ env.DO_REGISTRY }}/frontend:${{ github.sha }}
            strategy: basic
  ```

- 如需 SPA 刷新不 404，新增 `nginx.conf` 并在 Dockerfile 覆盖默认配置（`try_files $uri /index.html;`）。

## GitHub Secrets 需要配置
- `DOCR_USERNAME`: 一般为 `doadmin`
- `DOCR_TOKEN`: DOCR 访问 token（或 DO API token with write scope）
- `KUBECONFIG_BASE64`: 上述 base64 kubeconfig
- 可选：`SLACK_WEBHOOK` 发送通知

## 最小可行流程（手工验证）
1) 本地构建并推送测试镜像：
   ```bash
   docker build -t registry.digitalocean.com/<reg>/frontend:test .
   docker push registry.digitalocean.com/<reg>/frontend:test
   ```
2) 将 `deployment.yaml` 中镜像改为 `:test`，然后：
   ```bash
   kubectl apply -f k8s/cluster-issuer.yaml
   kubectl apply -f k8s/deployment.yaml
   kubectl apply -f k8s/service.yaml
   kubectl apply -f k8s/ingress.yaml
   kubectl get ingress
   ```
3) 访问 `https://fe.example.com`，确认 200；`kubectl describe certificate frontend-tls` 查看证书状态。

## 常见故障排查
- Ingress 404：确认 Nginx Ingress 安装、`kubernetes.io/ingress.class=nginx` 匹配。
- TLS Pending：检查域名解析是否指向 LB；看 `cert-manager` pod 日志，HTTP-01 路径是否能被访问。
- ImagePullBackOff：`do-regcred` secret 是否在同一 namespace，registry 域名是否一致。
- 刷新 404/空白页：Nginx 需 `try_files $uri $uri/ /index.html;`。
- 部署不更新：Deployment `imagePullPolicy: Always`，或执行 `kubectl rollout restart deploy/frontend`。

## 可选增强
- Terraform 管理 DOCR/DOKS/Ingress/证书。
- HPA 水平扩缩：基于 CPU/内存或自定义指标。
- 监控与日志：DO 托管 Prometheus/Grafana 或 Loki stack；Ingress Nginx 开启 access log。
- 回滚策略：GitHub Actions 加上上一个 tag 的回滚步骤；或 `kubectl rollout undo`.
