param(
    [string]$BaseUrl = "https://chat-production-43e3.up.railway.app",
    [string]$ClientId = "sv-test"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repoRoot ".env"

if (-not (Test-Path -LiteralPath $envPath)) {
    throw "Không tìm thấy file .env tại $envPath"
}

$tokenLine = Get-Content -LiteralPath $envPath |
    Where-Object { $_ -match '^API_TOKEN=' } |
    Select-Object -First 1

$env:API_TOKEN = if ($tokenLine) {
    ($tokenLine -replace '^API_TOKEN=', '').Trim().Trim('"')
} else {
    ''
}

if ([string]::IsNullOrWhiteSpace($env:API_TOKEN)) {
    throw "API_TOKEN trong .env đang rỗng"
}

function Get-StatusCode {
    param([string]$Uri)
    try {
        return [int](Invoke-WebRequest -Uri $Uri -Method Get -UseBasicParsing -TimeoutSec 60).StatusCode
    } catch {
        return [int]$_.Exception.Response.StatusCode.value__
    }
}

function Post-StatusCode {
    param(
        [string]$Uri,
        [byte[]]$Body,
        [hashtable]$Headers
    )
    try {
        return [int](Invoke-WebRequest -Uri $Uri -Method Post -Headers $Headers `
            -ContentType "application/json; charset=utf-8" -Body $Body `
            -UseBasicParsing -TimeoutSec 60).StatusCode
    } catch {
        return [int]$_.Exception.Response.StatusCode.value__
    }
}

$headers = @{
    Authorization = "Bearer $env:API_TOKEN"
    "X-Client-Id" = $ClientId
}
$authBody = [Text.Encoding]::UTF8.GetBytes((@{ message = "Deploy là gì?" } | ConvertTo-Json -Compress))
$rateBody = [Text.Encoding]::UTF8.GetBytes((@{ message = "rate" } | ConvertTo-Json -Compress))

$healthz = Get-StatusCode "$BaseUrl/healthz"
$readyz = Get-StatusCode "$BaseUrl/readyz"
$withoutToken = Post-StatusCode "$BaseUrl/chat" `
    ([Text.Encoding]::UTF8.GetBytes('{"message":"Hello"}')) @{}
$withToken = Post-StatusCode "$BaseUrl/chat" $authBody $headers
$burst = 1..15 | ForEach-Object {
    Post-StatusCode "$BaseUrl/chat" $rateBody $headers
}

Write-Output "healthz: $healthz"
Write-Output "readyz: $readyz"
Write-Output "chat without token: $withoutToken"
Write-Output "chat with token: $withToken"
Write-Output "rate limit (15 requests): $($burst -join ' ')"
