# Downloads the model packs from the GitHub release, checks their SHA-256, and unpacks them into models/.
#   powershell -ExecutionPolicy Bypass -File tools\fetch_models.ps1
# Re-running skips zips that are already downloaded and valid.
param(
    [string]$BaseUrl = '',
    [string]$Destination = ''
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # the progress bar makes Windows PowerShell's downloads very slow
$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content (Join-Path $PSScriptRoot 'models-manifest.json') -Raw | ConvertFrom-Json
$repo = 'ProfGrim/Poke-Farm'
$cache = Join-Path $root 'models-download'
$dest = if ($Destination) { $Destination } else { Join-Path $root 'models' }
if (-not $BaseUrl) { $BaseUrl = "https://github.com/$repo/releases/download/$($manifest.tag)" }
New-Item -ItemType Directory -Force $cache, $dest | Out-Null
foreach ($z in $manifest.zips) {
    $file = Join-Path $cache $z.name
    $ok = (Test-Path $file) -and ((Get-FileHash $file -Algorithm SHA256).Hash.ToLower() -eq $z.sha256)
    if (-not $ok) {
        Write-Host "Downloading $($z.name) ($([math]::Round($z.bytes / 1MB)) MB)..."
        Invoke-WebRequest "$BaseUrl/$($z.name)" -OutFile $file
        if ((Get-FileHash $file -Algorithm SHA256).Hash.ToLower() -ne $z.sha256) { throw "$($z.name) failed its checksum. Delete it and try again." }
    }
    Write-Host "Unpacking $($z.name)..."
    Expand-Archive $file -DestinationPath $dest -Force
}
if ($manifest.runtime) {
    $z = $manifest.runtime
    $file = Join-Path $cache $z.name
    $ok = (Test-Path $file) -and ((Get-FileHash $file -Algorithm SHA256).Hash.ToLower() -eq $z.sha256)
    if (-not $ok) {
        Write-Host "Downloading $($z.name) ($([math]::Round($z.bytes / 1MB)) MB)..."
        Invoke-WebRequest "$BaseUrl/$($z.name)" -OutFile $file
        if ((Get-FileHash $file -Algorithm SHA256).Hash.ToLower() -ne $z.sha256) { throw "$($z.name) failed its checksum. Delete it and try again." }
    }
    Write-Host "Unpacking runtime assets..."
    Expand-Archive $file -DestinationPath $root -Force
}
$n = (Get-ChildItem $dest -Filter *.glb).Count
Write-Host "Done: $n models in $dest (expected $($manifest.count)), plus runtime assets. You can delete models-download\ now."
