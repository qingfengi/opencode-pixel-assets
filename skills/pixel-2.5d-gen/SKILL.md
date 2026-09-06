---
name: pixel-2.5d-gen
description: 把现实物体/场景变成像素风、2.5D 风格游戏素材图时使用。流程：kimi-k3（备选 grok）把中文描述增强成英文生图提示词，再调 frimodel 的 gpt-image-2 系列生图，PNG 存到 output/。用户提到"像素风素材""2.5D 图标""把某个东西做成游戏道具图标""生成像素图"时触发。
---

# pixel-2.5d-gen

现实物体 → 像素风 / 2.5D 风格游戏素材图。

## 用法

```powershell
.\scripts\New-PixelImage.ps1 -Subject "一个红色复古电视机，带天线和旋钮" `
    -Style 2.5d -Size 1024x1024 -ImageModel gpt-image-2-medium
```

参数：

| 参数 | 说明 |
|---|---|
| `-Subject`（必填） | 物体描述，中英文均可 |
| `-Style` | `2.5d`（默认）/ `pixel` / `isometric` / `sprite` |
| `-Size` | `1024x1024` / `1536x1024` / `1024x1536` |
| `-ImageModel` | `gpt-image-2-low`（快、便宜）/ `-medium`（默认）/ `-high` / `-adobe` |
| `-Count N` | 一次生成 N 张同一提示词的变体 |
| `-NoEnhance` | 跳过 LLM 提示词增强，原文直发生图 API |
| `-OutDir` | 自定义输出目录，默认 `output/` |

产物：`output/<物体名>_<风格>_<时间戳>_n<i>.png`

## 管线结构

```
Subject(中文描述)
  → kimi-k3（失败自动切 grok）增强为英文 pixel/2.5D 提示词
    （关键词：clean pixel art, 16-24 color palette, crisp edges,
      soft shading fake gradient, normal-map-like lighting, game asset）
  → frimodel /v1/images/generations（gpt-image-2-*）
  → 下载 PNG 到 output/
```

## 配置文件

凭据在 `config.json`（不要提交到公开仓库）：

- `llm`：kimi-k3（bbroot 网关），注意模型名必须写全 `moonshotai/kimi-k3`，写 `k3` 会 404
- `llm_backup`：grok，同网关
- `image`：frimodel 网关，模型 gpt-image-2-low/medium/high/adobe

## 已知坑

1. PowerShell 5.1 调 API 时 body 必须 `[Text.Encoding]::UTF8.GetBytes()`，否则中文乱码/报 400。
2. 脚本文件必须保存为 UTF-8 **带 BOM**，否则 PS 5.1 解析中文报错。
3. bbroot 网关的 kimi-k3 偶发空响应，脚本已内置 grok 回退。
4. 生成参考图用先 `-ImageModel gpt-image-2-low` 试稿，满意后再换 `-high` 出成品，省钱。

## 多视角一致性（图生图）

8 方向视图必须走「参考图 + /v1/images/edits」，不能纯文生图循环：

```powershell
# 1. 先文生图出正面基准
.\scripts\New-PixelImage.ps1 -Subject "..." -Style 2.5d
# 2. 其余 7 个视角全部以正面为参考图
.\scripts\New-PixelVariant.ps1 -Reference output\01_front.png `
    -ViewAngle "left side view, 90 degrees profile" -OutName 03_left
```

- `New-PixelVariant.ps1` 用 multipart 把参考图 POST 到 `/v1/images/edits`
- prompt 里固定强调 "keep the exact same object, art style, pixel palette, proportions and lighting"
- 已验证 frimodel 支持 edits；8 视角序列：front → front-left → left → left-back → back → right-back → right → right-front（每 45°）

## 延伸方向（未实现）

- 真 3D 流程：手机环绕拍视频 → KIRI Engine / Polycam 出模型 → 本 skill 出 2.5D 贴图，素材一致性更好。
- 等距（isometric）四方向组图：`@('north','east','south','west')` 循环调脚本拼 RPG 角色/建筑四视图。
