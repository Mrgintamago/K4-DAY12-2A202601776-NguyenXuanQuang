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

function Invoke-FullRequest {
    param(
        [string]$Uri,
        [ValidateSet("Get", "Post")][string]$Method,
        [byte[]]$Body,
        [hashtable]$Headers = @{}
    )
    try {
        $response = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers `
            -ContentType "application/json; charset=utf-8" -Body $Body `
            -UseBasicParsing -TimeoutSec 60
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Body = $response.Content
        }
    } catch {
        $errorResponse = $_.Exception.Response
        $errorBody = ""
        if ($errorResponse) {
            $reader = New-Object System.IO.StreamReader($errorResponse.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            $reader.Close()
        }
        return [pscustomobject]@{
            StatusCode = if ($errorResponse) { [int]$errorResponse.StatusCode.value__ } else { 0 }
            Body = $errorBody
        }
    }
}

$headers = @{
    Authorization = "Bearer $env:API_TOKEN"
    "X-Client-Id" = $ClientId
}
$authBody = [Text.Encoding]::UTF8.GetBytes((@{ message = "Deploy là gì?" } | ConvertTo-Json -Compress))
$rateBody = [Text.Encoding]::UTF8.GetBytes((@{ message = "rate" } | ConvertTo-Json -Compress))

$healthz = Invoke-FullRequest "$BaseUrl/healthz" Get
$readyz = Invoke-FullRequest "$BaseUrl/readyz" Get
$withoutToken = Invoke-FullRequest "$BaseUrl/chat" Post `
    ([Text.Encoding]::UTF8.GetBytes('{"message":"Hello"}')) @{}
$withToken = Invoke-FullRequest "$BaseUrl/chat" Post $authBody $headers
$burst = 1..15 | ForEach-Object {
    [pscustomobject]@{
        Attempt = $_
        Result = Invoke-FullRequest "$BaseUrl/chat" Post $rateBody $headers
    }
}

Write-Output "=== Railway CP5 smoke test ==="
Write-Output "Base URL: $BaseUrl"
Write-Output "API token length: $($env:API_TOKEN.Length) (value hidden)"
Write-Output "`n--- GET /healthz ---"
Write-Output "Status: $($healthz.StatusCode)"
Write-Output "Body: $($healthz.Body)"
Write-Output "`n--- GET /readyz ---"
Write-Output "Status: $($readyz.StatusCode)"
Write-Output "Body: $($readyz.Body)"
Write-Output "`n--- POST /chat without token ---"
Write-Output "Status: $($withoutToken.StatusCode)"
Write-Output "Body: $($withoutToken.Body)"
Write-Output "`n--- POST /chat with token ---"
Write-Output "Status: $($withToken.StatusCode)"
Write-Output "Body: $($withToken.Body)"
Write-Output "`n--- POST /chat rate limit (15 requests) ---"
foreach ($item in $burst) {
    Write-Output ("Attempt {0}: {1} {2}" -f $item.Attempt, $item.Result.StatusCode, $item.Result.Body)
}
