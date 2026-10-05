#requires -Version 5.1
<#
.SYNOPSIS
  Fetch the Cubism SDK subset required by the in-repo Live2D renderer.

.DESCRIPTION
  Reads third_party/live2d.sdk.json and materialises the needed subset into
  third_party/live2d/ (which is gitignored, so the SDK is never committed).

  Default source: the pinned pub.dev archive. pub.dev's API hands out both
  archive_url and archive_sha256, so the download is verifiable.

  Official fallback: the Live2D "Cubism SDK for Native" zip sits behind a
  license-acceptance page and cannot be fetched by a stable direct link. Point
  -SdkZip (or LIVE2D_SDK_ZIP) at a manually downloaded zip instead.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\fetch_live2d_sdk.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\fetch_live2d_sdk.ps1 -SdkZip D:\CubismSdkForNative.zip

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\fetch_live2d_sdk.ps1 -Force
#>
[CmdletBinding()]
param(
  # Manually downloaded SDK zip (official or pub archive). Skips networking.
  [string] $SdkZip = $env:LIVE2D_SDK_ZIP,
  # Re-fetch even when third_party/live2d/ already looks complete.
  [switch] $Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'third_party\live2d.sdk.json'
$destRoot = Join-Path $repoRoot 'third_party\live2d'
$readyMarker = Join-Path $destRoot '.ready'
$staging = Join-Path $env:TEMP ("live2d-sdk-" + [guid]::NewGuid().ToString('N'))

function Write-Step([string] $msg) { Write-Host "==> $msg" }
function Write-Detail([string] $msg) { Write-Host "    $msg" -ForegroundColor DarkGray }

if (-not (Test-Path $manifestPath)) { throw "manifest not found: $manifestPath" }
# -Encoding UTF8 is required: Windows PowerShell 5.1 otherwise reads the file as
# ANSI and mangles the non-ASCII comment, producing invalid JSON.
$manifest = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ((Test-Path $readyMarker) -and -not $Force) {
  Write-Step 'third_party/live2d already present (use -Force to re-fetch)'
  exit 0
}

function Get-Sha256([string] $path) {
  return (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# -- 1. Obtain the archive ---------------------------------------------------
$archive = $SdkZip
$expectedSha = $null

if ($archive) {
  if (-not (Test-Path $archive)) { throw "zip not found: $archive" }
  Write-Step "using local zip: $archive"
} else {
  if ($manifest.source -ne 'pub.dev') { throw "unknown source: $($manifest.source)" }
  $api = "https://pub.dev/api/packages/$($manifest.package)/versions/$($manifest.version)"
  Write-Step "querying pub.dev: $api"
  $meta = Invoke-RestMethod -Uri $api -UseBasicParsing
  $archiveUrl = $meta.archive_url
  $expectedSha = $meta.archive_sha256
  if (-not $archiveUrl) { throw 'pub.dev returned no archive_url' }

  if ($manifest.archiveSha256 -and ($manifest.archiveSha256 -ne $expectedSha)) {
    throw "pinned sha256 differs from pub.dev`n  pinned: $($manifest.archiveSha256)`n  remote: $expectedSha"
  }

  New-Item -ItemType Directory -Path $staging -Force | Out-Null
  $archive = Join-Path $staging 'sdk.tar.gz'
  Write-Step 'downloading archive'
  Invoke-WebRequest -Uri $archiveUrl -OutFile $archive -UseBasicParsing
  Write-Detail $archiveUrl
}

# -- 2. Verify ---------------------------------------------------------------
if ($expectedSha) {
  Write-Step 'verifying sha256'
  $actual = Get-Sha256 $archive
  if ($actual -ne $expectedSha) { throw "sha256 mismatch`n  expected: $expectedSha`n  actual:   $actual" }
  Write-Detail $actual
} else {
  Write-Detail ("sha256 = " + (Get-Sha256 $archive) + " (local zip, not compared to a remote)")
}

# -- 3. Unpack to staging ----------------------------------------------------
$unpacked = Join-Path $staging 'unpacked'
New-Item -ItemType Directory -Path $unpacked -Force | Out-Null
Write-Step 'unpacking'
if ($archive.EndsWith('.zip')) {
  Expand-Archive -Path $archive -DestinationPath $unpacked -Force
} else {
  & tar -xzf $archive -C $unpacked
  if ($LASTEXITCODE -ne 0) { throw "tar failed (exit $LASTEXITCODE)" }
}

# Some archives wrap everything in a single top-level folder; detect that.
$archiveRoot = $unpacked
$inner = @(Get-ChildItem $unpacked -Force | Where-Object { $_.PSIsContainer })
if (($inner.Count -eq 1) -and -not (Test-Path (Join-Path $unpacked 'android'))) {
  $archiveRoot = $inner[0].FullName
  Write-Detail "archive root: $(Split-Path -Leaf $archiveRoot)"
}

# -- 4. Copy only the declared subset ----------------------------------------
$include = @($manifest.include)
$exclude = @($manifest.exclude)
$script:copied = 0

function Test-Excluded([string] $relative) {
  # Normalise to forward slashes: -like is separator-sensitive and the manifest
  # paths are written POSIX-style, while Windows paths come back with '\'.
  $normalized = $relative.Replace('\', '/')
  foreach ($pattern in $exclude) {
    if ($normalized -like "*$pattern*") { return $true }
  }
  return $false
}

if (Test-Path $destRoot) { Remove-Item $destRoot -Recurse -Force }
New-Item -ItemType Directory -Path $destRoot -Force | Out-Null

Write-Step 'copying subset'
foreach ($entry in $include) {
  $source = Join-Path $archiveRoot $entry
  if (-not (Test-Path $source)) {
    Write-Host "    skipped (not in archive): $entry" -ForegroundColor Yellow
    continue
  }
  if ((Get-Item $source).PSIsContainer) {
    Get-ChildItem $source -Recurse -File | ForEach-Object {
      $relative = $_.FullName.Substring($archiveRoot.Length).TrimStart('\', '/')
      if (Test-Excluded $relative) { return }
      $outFile = Join-Path $destRoot $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $outFile) -Force | Out-Null
      Copy-Item $_.FullName $outFile -Force
      $script:copied++
    }
  } else {
    $outFile = Join-Path $destRoot $entry
    New-Item -ItemType Directory -Path (Split-Path -Parent $outFile) -Force | Out-Null
    Copy-Item $source $outFile -Force
    $script:copied++
  }
}

if ($script:copied -eq 0) { throw 'nothing was copied - manifest include paths do not match the archive layout' }
Write-Detail "$($script:copied) files"

# -- 5. Self-check -----------------------------------------------------------
Write-Step 'self-check'
$required = @(
  'android/src/main/cpp/CubismCore/include/Live2DCubismCore.h',
  'android/src/main/cpp/CubismFramework/CubismFramework.hpp',
  'windows/libs/x86_64/143/Live2DCubismCore_MD.lib',
  'windows/libs/x86_64/143/Live2DCubismCore_MDd.lib'
)
$missing = @($required | Where-Object { -not (Test-Path (Join-Path $destRoot $_)) })
if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "    missing: $_" -ForegroundColor Red }
  throw 'SDK subset is incomplete.'
}
$required | ForEach-Object { Write-Detail $_ }

# The Live2D license files must ship with the SDK copy.
$licenseHits = @(Get-ChildItem $destRoot -Recurse -File | Where-Object { $_.Name -match 'LICENSE' })
if ($licenseHits.Count -gt 0) {
  Write-Detail "$($licenseHits.Count) license file(s) carried over"
} else {
  Write-Host '    warning: no LICENSE file found - check redistribution compliance' -ForegroundColor Yellow
}

$stamp = "fetched-at=$(Get-Date -Format o)`npackage=$($manifest.package)`nversion=$($manifest.version)"
Set-Content -Path $readyMarker -Value $stamp -Encoding UTF8
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

Write-Step "done: $destRoot"
