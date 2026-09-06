# 像素素材生成脚本
# 用法：把 API key 和端点填进下方两处（或设环境变量），然后：
#   python pixel_gen.py "像素小人举着一个发光的存档图标" -o out\s01_char.png
#
# 端点说明：
#   - 火山引擎方舟（Seedream/Seedance 图像模型）默认即可，已内置
#   - 如果给的是别的 OpenAI 兼容接口，用 --base-url 和 --model 换
#   - key 建议放环境变量 ARK_API_KEY，别写进代码里提交

import argparse
import base64
import json
import os
import sys
import urllib.request
from pathlib import Path

DEFAULT_BASE_URL = "https://ark.cn-beijing.volces.com/api/v3"
DEFAULT_MODEL = "doubao-seedream-4-0-250828"

PIXEL_STYLE = (
    "pixel art, 8px pixel grid, flat shading, limited palette, "
    "no anti-aliasing, no gradient, hard edges, "
    "transparent background, game sprite style, side view"
)
NEGATIVE_GUARD = "no blur, no outline glow, no realistic shading"


def build_prompt(user_desc: str) -> str:
    return f"{user_desc}, {PIXEL_STYLE}, avoid: {NEGATIVE_GUARD}"


def main() -> int:
    ap = argparse.ArgumentParser(description="像素风素材生图")
    ap.add_argument("desc", help="画面描述（中文即可）")
    ap.add_argument("-o", "--out", required=True, help="输出 png 路径")
    ap.add_argument("--size", default="1024x1024", help="如 1024x1024 / 2048x2048")
    ap.add_argument("--base-url", default=os.environ.get("PIXEL_GEN_BASE_URL", DEFAULT_BASE_URL))
    ap.add_argument("--model", default=os.environ.get("PIXEL_GEN_MODEL", DEFAULT_MODEL))
    ap.add_argument("--no-style", action="store_true", help="不自动追加像素风提示词")
    args = ap.parse_args()

    api_key = os.environ.get("ARK_API_KEY") or os.environ.get("PIXEL_GEN_API_KEY")
    if not api_key:
        print("错误：未设置 ARK_API_KEY 环境变量。先设好 key 再跑。", file=sys.stderr)
        return 2

    prompt = args.desc if args.no_style else build_prompt(args.desc)
    payload = {
        "model": args.model,
        "prompt": prompt,
        "size": args.size,
        "response_format": "b64_json",
    }

    req = urllib.request.Request(
        url=args.base_url.rstrip("/") + "/images/generations",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            # 部分中转站开了 Cloudflare，不带 UA 会被 403/1010 拦
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"接口报错 HTTP {e.code}: {body[:500]}", file=sys.stderr)
        return 1

    item = data["data"][0]
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    if item.get("b64_json"):
        out.write_bytes(base64.b64decode(item["b64_json"]))
    elif item.get("url"):
        with urllib.request.urlopen(
            urllib.request.Request(item["url"], headers={"User-Agent": "Mozilla/5.0"}), timeout=120
        ) as resp:
            out.write_bytes(resp.read())
    else:
        print("返回里没有图像数据，实际返回:", json.dumps(data, ensure_ascii=False)[:500], file=sys.stderr)
        return 1
    print(f"OK -> {out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
