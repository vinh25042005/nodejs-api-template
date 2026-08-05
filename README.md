# nodejs-api — Golden Path Template (IDP)

Template Node.js API theo **golden path** của IDP. Dev dùng nó để sinh repo mới
mà không cần nghĩ về CI/CD, Helm, signing, rollout.

## Cấu trúc

```
├── .github/workflows/ci.yml   # CI: test → build → push → cosign sign → update gitops
├── src/                       # Express app + /health + /metrics (prom-client)
├── test/                      # node --test (không cần framework thêm)
├── scripts/update-image.sh    # commit image tag vào gitops repo
├── Dockerfile                 # multi-stage, non-root, dumb-init
└── helm/nodejs-api/           # chart nhẹ per-service (Rollout canary + AnalysisTemplate)
```

## Tạo repo mới từ template

1. Push repo này lên GitHub và bật **Settings → General → Template repository**.
2. Dev bấm **"Use this template"** → có repo mới.
3. Đổi theo service của mình:

| Chỗ cần sửa | Chi tiết |
|---|---|
| `package.json` | `name` → tên service |
| `helm/nodejs-api/` | đổi tên thư mục + `Chart.yaml` `name` → tên service |
| `helm/nodejs-api/values.yaml` | `image.repository` → registry thật |
| `helm/nodejs-api/env/values-*.yaml` | `namespace`, `ingress.host` thật |

> ⚠️ Giữ cờ `# IMAGE_TAG_ANCHOR` trên dòng `tag:` trong `values.yaml` —
> script `update-image.sh` dựa vào cờ này để cập nhật tag.

## Secrets (optional) trong repo GitHub

- **Build/push/Trivy/SBOM:** không cần secret (GHCR dùng `GITHUB_TOKEN`).
- `COSIGN_PRIVATE_KEY` + `COSIGN_PASSWORD` → ký image (cosign sign + attach SBOM). Chưa set thì CI bỏ qua bước này, không fail.
- `SONAR_TOKEN` + `SONAR_HOST_URL` → job SonarQube scan. Chưa set thì job bị skip.

> Bước sau (nối ArgoCD): thêm `GITOPS_REPO`/`GITOPS_DEPLOY_KEY` để commit tag vào gitops repo.

## Luồng CI/CD

```
merge main → test → build :<sha> → push GHCR → Trivy → SBOM → cosign sign
tag v*     → test → build :<tag> → push GHCR → Trivy → SBOM → cosign sign
PR         → chỉ chạy test
```

SonarQube scan chạy job riêng (`sonar`) khi có secret `SONAR_TOKEN`.
Image: `ghcr.io/<owner>/<repo>:{sha|tag}`.

## Chạy cục bộ

```bash
npm ci
npm test          # node --test
npm start         # curl localhost:8080/health
```

## Validate Helm chart

```bash
helm template nodejs-api helm/nodejs-api -f helm/nodejs-api/env/values-dev.yaml
```
