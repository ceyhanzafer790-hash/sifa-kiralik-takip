param([string]$Email)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Bu betik PowerShell Yonetici olarak acilarak calistirilmali."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Step "Docker kontrolu"
docker version | Out-Null
docker compose version | Out-Null

Write-Step "Guncel public IP"
$publicIp = (Invoke-RestMethod "https://api.ipify.org").Trim()
if ($publicIp -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
    throw "Public IPv4 alinamadi: $publicIp"
}
Write-Host "Public IP: $publicIp"

if ([string]::IsNullOrWhiteSpace($Email)) {
    $Email = Read-Host "Let's Encrypt hesabi icin e-posta adresini yaz"
}
if ([string]::IsNullOrWhiteSpace($Email)) {
    throw "E-posta bos olamaz."
}

Write-Step "Gecici test containerlari kapatiliyor"
docker rm -f sifa-port-test 2>$null | Out-Null
docker rm -f sifa-port443-test 2>$null | Out-Null
docker compose -f docker-compose.yml -f docker-compose.ip.yml stop caddy 2>$null | Out-Null

Write-Step "Windows guvenlik duvari"
Get-NetFirewallRule -DisplayName "Sifa HTTPS 443" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Sifa HTTPS 443" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow | Out-Null

Write-Step "Sertifika volume"
docker volume inspect sifa_ipcerts 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    docker volume create sifa_ipcerts | Out-Null
}

Write-Step "Let's Encrypt IP sertifikasi"
docker run --rm -p 443:443 -v sifa_ipcerts:/var/lib/lego goacme/lego:v5.5.1 --email "$Email" --domains "$publicIp" --tls --profile "shortlived" --path "/var/lib/lego" --accept-tos run
if ($LASTEXITCODE -ne 0) {
    throw "Sertifika alma islemi basarisiz oldu."
}

Write-Step "Sertifika dosyalari kontrol ediliyor"
docker run --rm -v sifa_ipcerts:/data alpine sh -c "test -s /data/certificates/$publicIp.crt && test -s /data/certificates/$publicIp.key"
if ($LASTEXITCODE -ne 0) {
    throw "Sertifika veya private key volume icinde bulunamadi."
}

Write-Step ".env guncelleniyor"
$envPath = Join-Path $repoRoot ".env"
if (-not (Test-Path $envPath)) {
    throw ".env bulunamadi: $envPath"
}

$envLines = [System.Collections.Generic.List[string]](Get-Content $envPath)

function Set-EnvValue([string]$Name, [string]$Value) {
    for ($i = 0; $i -lt $envLines.Count; $i++) {
        if ($envLines[$i] -match "^$([regex]::Escape($Name))=") {
            $envLines[$i] = "$Name=$Value"
            return
        }
    }
    $envLines.Add("$Name=$Value")
}

Set-EnvValue "API_IP" $publicIp
Set-EnvValue "LEGO_EMAIL" $Email
[System.IO.File]::WriteAllLines($envPath, $envLines, (New-Object System.Text.UTF8Encoding($false)))

Write-Step "Sifa API ve Caddy baslatiliyor"
docker compose -f docker-compose.yml -f docker-compose.ip.yml up -d --build api caddy

Write-Step "HTTPS health bekleniyor"
$healthy = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    $healthText = curl.exe --fail --silent --show-error --resolve "$($publicIp):443:127.0.0.1" "https://$publicIp/health" 2>$null
    if ($LASTEXITCODE -eq 0 -and $healthText -match '"status"\s*:\s*"ok"') {
        $healthy = $true
        Write-Host $healthText
        break
    }
    Write-Host "Bekleniyor..."
}

if (-not $healthy) {
    Write-Host ""
    Write-Host "HTTPS health testi basarisiz. Caddy loglari:" -ForegroundColor Red
    docker compose -f docker-compose.yml -f docker-compose.ip.yml logs --tail=150 caddy
    exit 1
}

Write-Host ""
Write-Host "SIFA PC SUNUCUSU HTTPS ILE HAZIR" -ForegroundColor Green
Write-Host "API: https://$publicIp"
Write-Host "Health: https://$publicIp/health"
