param(
    [Parameter(Mandatory = $true)][string]$Reference,   # 参考图路径
    [Parameter(Mandatory = $true)][string]$ViewAngle,   # 目标视角描述，如 "left side view, 90 degrees"
    [string]$ImageModel = "gpt-image-2-medium",
    [string]$Size = "1024x1024",
    [string]$OutName = "",                              # 输出名（不含扩展名）
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$skillDir = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $skillDir "config.json") -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $OutDir) { $OutDir = Join-Path $skillDir "output" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
if (-not $OutName) { $OutName = "variant_" + (Get-Date -Format "yyyyMMdd_HHmmss") }

$prompt = "Keep the exact same object, art style, pixel palette, proportions and lighting as the reference image. Only change the camera angle: $ViewAngle. Clean pixel art, 2.5D look, plain background."

Add-Type -AssemblyName System.Net.Http
$cli = New-Object System.Net.Http.HttpClient
$cli.Timeout = [TimeSpan]::FromSeconds(300)
$cli.DefaultRequestHeaders.Authorization = `
    New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $config.image.api_key)

$content = New-Object System.Net.Http.MultipartFormDataContent
$content.Add((New-Object System.Net.Http.StringContent($ImageModel)), "model")
$content.Add((New-Object System.Net.Http.StringContent($prompt)), "prompt")
$content.Add((New-Object System.Net.Http.StringContent($Size)), "size")
$fs = [System.IO.File]::OpenRead($Reference)
$fc = New-Object System.Net.Http.StreamContent($fs)
$fc.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("image/png")
$content.Add($fc, "image[]", [IO.Path]::GetFileName($Reference))

$resp = $cli.PostAsync("$($config.image.base_url)/images/edits", $content).Result
$txt = $resp.Content.ReadAsStringAsync().Result
$fs.Close()

if (-not $resp.IsSuccessStatusCode) {
    Write-Error "edits API failed: HTTP $($resp.StatusCode) - $txt"
}

$url = ($txt | ConvertFrom-Json).data[0].url
$file = Join-Path $OutDir ($OutName + ".png")
Invoke-WebRequest -Uri $url -OutFile $file -TimeoutSec 120
Write-Host "[saved] $file"
