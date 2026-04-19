# MinIO 种子：表情商店矢量贴纸

本目录仅包含 **桶 `file`** 下 **`preview/sticker/`** 的静态对象（逻辑文件约 13MB、500+ 个文件），由 `mc mirror` 从 MinIO 导出，与 `chinaim-server` 里 `sticker_store` 元数据中的路径一致。

- **不要**把整份 `miniodata/`（含用户头像、聊天文件等）提交到 Git；业务数据仍用本地 volume。
- 新机器 clone 后：先 `docker compose up -d` 起 MinIO，再执行仓库根目录下：

  ```bash
  sh scripts/seed-sticker-store-to-minio.sh
  ```

  脚本会用 `minio/mc` 镜像把 `seed/minio-file-bucket/preview/sticker/` 同步进运行中的 MinIO 容器（需已配置 `.env` 中的 `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`）。
