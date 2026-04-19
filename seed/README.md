# MinIO 种子：表情商店矢量贴纸

本目录仅包含 **桶 `file`** 下 **`preview/sticker/`** 的静态对象（逻辑文件约 13MB、500+ 个文件），由 `mc mirror` 从 MinIO 导出，与 `chinaim-server` 里 `sticker_store` 元数据中的路径一致。

- **不要**把整份 `miniodata/`（含用户头像、聊天文件等）提交到 Git；业务数据仍用本地 volume。
- 新机器 clone 后：先 `docker compose up -d minio`，再任选其一：
  - **推荐**：`docker compose --profile seed run --rm sticker-seed`（见根目录 `docker-compose.yaml` 中 `sticker-seed` 服务）；
  - **备选**：`sh scripts/seed-sticker-store-to-minio.sh`（宿主机起 `minio/mc` 并挂到 MinIO 容器网络）。

  均需已在 `.env` 中配置 `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`。
