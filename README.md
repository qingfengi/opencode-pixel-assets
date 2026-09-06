# Opencode 像素风素材生成 Skill 与生成素材存档

从本机 Opencode（`C:\Users\xuqingfeng\Documents\Default Project\.opencode\skills\`）整理备份的
像素风 / 2.5D 素材生成相关 Skill、提示词规范与已生成的图片、视频素材。

## 目录结构

```
opencode-pixel-assets/
├── README.md
├── .gitignore
└── skills/
    ├── pixel-2.5d-gen/            # 现实物体 → 像素风 / 2.5D 游戏素材图
    │   ├── SKILL.md               # Skill 说明：提示词增强管线（kimi-k3/grok → gpt-image-2）
    │   ├── config.example.json    # 配置模板（真实 config.json 含 API Key，不入库）
    │   ├── scripts/
    │   │   ├── New-PixelImage.ps1     # 文生图：中文描述 → 英文像素风提示词 → 生图
    │   │   ├── New-PixelVariant.ps1   # 图生图：以正面图为参考生成其余 7 个视角
    │   │   └── render_turntable.py    # 用 TripoSR 把 2.5D 图转 3D 模型并渲染转台视频
    │   ├── triposr/               # TripoSR 3D 重建依赖（官方开源代码）
    │   └── output/                # 已生成的素材
    │       ├── 一个红色复古电视机_带天线和旋钮_2.5d_*.png
    │       ├── 一台复古街机_*_2.5d_*.png
    │       ├── 01_front.png ~ 08_right-front.png   # 8 方向多视角一致视图
    │       ├── triposr/0/         # 3D 转换产物：mesh.obj / model.glb / texture / turntable.gif / render.mp4
    │       └── triposr_hd/0/      # 高清版 3D 转换产物
    └── concept-explainer-video/   # 像素风动画科普短片 Skill（视频素材方向）
        ├── SKILL.md               # 90 秒结构模板、像素风美术规范、生图提示词模板、动效脚本
        ├── pixel_gen.py           # 像素风素材生图脚本（火山方舟 Seedream）
        └── templates/             # 动效脚本模板
```

## 素材清单（生成结果）

| 类型 | 文件 | 说明 |
|---|---|---|
| 主图 | `一个红色复古电视机_..._2.5d_20260905_133429_n1.png` | 文生图成品（电视机） |
| 主图 | `一台复古街机_..._2.5d_20260905_134307_n1.png` | 文生图成品（街机） |
| 多视角 | `01_front.png` ~ `08_right-front.png` | 同一物体 8 方向一致视图（每 45°） |
| 3D 模型 | `triposr/0/mesh.obj`、`model.glb` | TripoSR 重建的 3D 网格 |
| 转台动画 | `triposr/0/turntable.gif`、`triposr_hd/0/turntable.gif` | 旋转展示 GIF |
| 视频 | `triposr/0/render.mp4` | 转台渲染视频 |
| 贴图 | `texture.png` | 3D 模型贴图 |

## 使用方式

```powershell
# 1. 复制配置模板并填入 API Key（真实 config.json 未入库，保护密钥）
Copy-Item skills\pixel-2.5d-gen\config.example.json skills\pixel-2.5d-gen\config.json
# 编辑 config.json 填入 llm / llm_backup / image 三个网关的 base_url 与 api_key

# 2. 生成像素风 / 2.5D 素材图
.\scripts\New-PixelImage.ps1 -Subject "一个红色复古电视机，带天线和旋钮" -Style 2.5d -Size 1024x1024

# 3. 以正面图为参考生成 8 方向一致视图
.\scripts\New-PixelVariant.ps1 -Reference output\01_front.png -ViewAngle "left side view, 90 degrees profile" -OutName 03_left
```

> 注意：`output/triposr/` 与 `output/triposr_hd/` 中的 `render_*.png` 为转台渲染的中间帧，
> `mesh.obj`（66 MB）体积较大，如需精简可删除后重新 push。

## 安全说明

- 真实 `config.json` 含 3 组 API Key（kimi/grok/frimodel），按惯例**不提交到任何仓库**（含私有仓库），
  已替换为 `config.example.json` 占位模板。使用前自行填入。
- `venv/`（约 5 GB 虚拟环境）与 `node_modules/` 不随仓库备份，需要时按 `requirements.txt` 重建。
