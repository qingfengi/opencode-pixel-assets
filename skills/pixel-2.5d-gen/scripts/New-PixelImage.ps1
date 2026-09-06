param(
    [Parameter(Mandatory = $true)][string]$Subject,
    [string]$Style = "2.5d",            # 2.5d | pixel | isometric | sprite
    [string]$Size = "1024x1024",        # 1024x1024 | 1536x1024 | 1024x1536
    [string]$ImageModel = "",           # gpt-image-2-low/medium/high/adobe，默认读 config
    [switch]$NoEnhance,                 # 跳过 LLM 提示词增强，直接用原始描述
    [int]$Count = 1,
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$skillDir = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $skillDir "config.json") -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $OutDir) { $OutDir = Join-Path $skillDir "output" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
if (-not $ImageModel) { $ImageModel = $config.image.model }

function Invoke-ChatCompletion {
    param($Cfg, [string]$Model, [string]$UserText)
    $payload = @{
        model    = $Model
        messages = @(
            @{ role = "system"; content = "你是像素美术/游戏美术提示词专家。把用户给的物体描述改写成一段英文图片生成提示词，输出像素风格 / 2.5D 风格素材。要求：clean pixel art, limited color palette (16-24 colors), crisp edges, soft shading fake gradient, studio lighting, plain background, game asset。像素画加 'pixel art, no anti-aliasing'；2.5D 加 '2.5D look, slight dimensional shading, normal-map-like lighting'。只输出提示词本身，不要解释。" },
            @{ role = "user"; content = $UserText }
        )
    } | ConvertTo-Json -Depth 6
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $resp = Invoke-RestMethod -Uri "$($Cfg.base_url)/chat/completions" -Method Post `
        -Headers @{ "Authorization" = "Bearer $($Cfg.api_key)"; "Content-Type" = "application/json" } `
        -Body $bytes -TimeoutSec 120
    return $resp.choices[0].message.content.Trim()
}

# --- 1. LLM 增强提示词 ---
if ($NoEnhance) {
    $prompt = $Subject
} else {
    try {
        $prompt = Invoke-ChatCompletion -Cfg $config.llm -Model $config.llm.model -UserText "风格：$Style。物体：$Subject"
        Write-Host "[prompt via kimi-k3] $prompt"
    } catch {
        Write-Warning "k3 不可用，尝试 grok..."
        try {
            $prompt = Invoke-ChatCompletion -Cfg $config.llm -Model $config.llm_backup.model -UserText "Style: $Style. Object: $Subject"
            Write-Host "[prompt via grok] $prompt"
        } catch {
            Write-Warning "LLM 增强失败，使用原始描述。"
            $prompt = "$Subject, $Style style game asset"
        }
    }
}

# --- 2. 调生图 API ---
foreach ($i in 1..$Count) {
    $body = @{
        model  = $ImageModel
        prompt = $prompt
        size   = $Size
        n      = 1
    } | ConvertTo-Json
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $r = Invoke-RestMethod -Uri "$($config.image.base_url)/images/generations" -Method Post `
        -Headers @{ "Authorization" = "Bearer $($config.image.api_key)"; "Content-Type" = "application/json" } `
        -Body $bytes -TimeoutSec 180

    $url = $r.data[0].url
    if (-not $url) { Write-Error "API 未返回图片 URL: $($r | ConvertTo-Json -Depth 6)" }

    $safeName = ($Subject -replace '[^\w一-鿿 -]', '_') -replace '\s+', '_'
    if ($safeName.Length -gt 20) { $safeName = $safeName.Substring(0, 20).TrimEnd('_') }
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = Join-Path $OutDir ("{0}_{1}_{2}_n{3}.png" -f $safeName, $Style, $stamp, $i)
    Invoke-WebRequest -Uri $url -OutFile $file -TimeoutSec 120
    Write-Host "[saved] $file"
}
