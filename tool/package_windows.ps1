#requires -Version 5.1
<#
.SYNOPSIS
  Package the Windows release build into a distributable zip (plus an installer
  when Inno Setup is available).

.DESCRIPTION
  Runs a pre-flight check on the release output before packaging. That check
  exists because of a real incident: a Release directory had a DEBUG engine DLL
  (43 MB) next to a Release exe and an AOT snapshot, so the app died at startup
  with "Not running in AOT mode but could not resolve the kernel binary" and
  looked simply "broken". The script now refuses to package such a directory.

  It also drops stale plugin DLLs (plugins this repo no longer builds - the
  CMake install step does not delete them) and runtime logs.

  Everything is staged into a temporary directory first, so the build output is
  never mutated by packaging.

  This file is deliberately ASCII-only: Windows PowerShell 5.1 reads .ps1 files
  as ANSI unless they carry a BOM, which mangles non-ASCII text and breaks the
  parser.

.PARAMETER Clean
  Run `flutter clean` first. Flutter does not prune removed plugins' outputs or
  assets from an existing build directory (this is what produced the mixed
  configuration the pre-flight check guards against), so a distributable built
  from a long-lived build directory can carry stale files. Cleaning before a
  build is the only complete fix; it costs a full rebuild.

.PARAMETER SkipBuild
  Package the existing build instead of running `flutter build windows --release`.

.PARAMETER KeepStaging
  Keep the staging directory (for inspecting what actually gets packaged).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\package_windows.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\package_windows.ps1 -SkipBuild
#>
[CmdletBinding()]
param(
  [switch] $Clean,
  [switch] $SkipBuild,
  [switch] $KeepStaging
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$release = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$staging = Join-Path $env:TEMP ("desktop-pet-package-" + [guid]::NewGuid().ToString('N'))
$distDir = Join-Path $repoRoot 'dist'

function Write-Step([string] $msg) { Write-Host "==> $msg" }
function Write-Detail([string] $msg) { Write-Host "    $msg" -ForegroundColor DarkGray }
function Fail([string] $msg) { throw $msg }

# Locates the MSVC runtime DLLs for app-local deployment (the Microsoft.VC*.CRT
# folder). The exe and every plugin DLL are built /MD, so a machine without the
# VC++ 2015-2022 x64 Redistributable cannot start the app at all
# (VCRUNTIME140.dll / MSVCP140.dll missing). Copying the CRT next to the exe is
# the redistributor-approved way to make the package self-contained. Switching
# the app to /MT is not an option: the Cubism Core is shipped as MD/MDd only.
function Find-VcRuntimeDir {
  $roots = @()
  if ($env:VCToolsRedistDir) { $roots += $env:VCToolsRedistDir }
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($vs) { $roots += (Join-Path $vs 'VC\Redist\MSVC') }
  }
  $roots += @("${env:ProgramFiles}\Microsoft Visual Studio", 'E:\Microsoft Visual Studio')
  foreach ($root in $roots) {
    if (-not $root -or -not (Test-Path $root)) { continue }
    $crt = Get-ChildItem -Path $root -Recurse -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\x64\\' } |
      Sort-Object FullName -Descending | Select-Object -First 1
    if ($crt) { return $crt.FullName }
  }
  return $null
}

# ---- 1. version + build -----------------------------------------------------
$pubspec = Get-Content (Join-Path $repoRoot 'pubspec.yaml') -Raw -Encoding UTF8
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
  Fail 'could not read `version:` from pubspec.yaml'
}
$version = $Matches[1]

if ($Clean) {
  if ($SkipBuild) { Fail '-Clean and -SkipBuild cannot be combined' }
  Write-Step 'flutter clean'
  & flutter clean
  if ($LASTEXITCODE -ne 0) { Fail "flutter clean failed (exit $LASTEXITCODE)" }
}

if (-not $SkipBuild) {
  Write-Step "building release ($version)"
  & flutter build windows --release
  if ($LASTEXITCODE -ne 0) { Fail "flutter build failed (exit $LASTEXITCODE)" }
} else {
  Write-Step 'reusing the existing release build (-SkipBuild)'
}

# ---- 2. pre-flight ---------------------------------------------------------
Write-Step 'pre-flight'
foreach ($required in @(
    'desktop_pet.exe',
    'flutter_windows.dll',
    'pet_live2d_plugin.dll',
    'data\app.so',
    'data\icudtl.dat',
    'data\flutter_assets',
    'FrameworkShaders\CubismEffect.fx'
  )) {
  if (-not (Test-Path (Join-Path $release $required))) {
    Fail "release output is incomplete: missing $required (run without -SkipBuild)"
  }
}
Write-Detail 'core files present'

# A DEBUG engine DLL next to a Release exe is the failure mode described above.
# The Release/Profile engine is ~20 MB; the Debug one is ~43 MB.
$engine = Get-Item (Join-Path $release 'flutter_windows.dll')
$engineMb = [math]::Round($engine.Length / 1MB, 1)
if ($engine.Length -gt 30MB) {
  Fail ("flutter_windows.dll is $engineMb MB - that is the DEBUG engine, not the release one." + "`n" +
        "  The release output is a mixed-configuration directory." + "`n" +
        "  Fix: flutter clean  (or delete build\windows), then rebuild with --release.")
}
Write-Detail "engine dll: $engineMb MB"

# ---- 3. stage --------------------------------------------------------------
Write-Step 'staging'
New-Item -ItemType Directory -Path $staging -Force | Out-Null
Copy-Item (Join-Path $release '*') $staging -Recurse -Force

# Plugin DLLs this repo still builds, per the generated plugin list.
$pluginList = Get-Content (Join-Path $repoRoot 'windows\flutter\generated_plugins.cmake') -Raw
$expectedPlugins = @()
$inList = $false
foreach ($line in ($pluginList -split "`n")) {
  if ($line -match 'list\(APPEND FLUTTER_PLUGIN_LIST') { $inList = $true; continue }
  if ($inList) {
    if ($line -match '^\s*\)') { $inList = $false; continue }
    $name = $line.Trim()
    if ($name) { $expectedPlugins += "${name}_plugin.dll" }
  }
}

# Every plugin the build is supposed to produce must actually be here: a build
# that silently dropped one would otherwise ship without that feature.
$missing = @($expectedPlugins | Where-Object { -not (Test-Path (Join-Path $release $_)) })
if ($missing.Count -gt 0) {
  Fail "release output is missing plugin DLL(s): $($missing -join ', ')"
}

$stale = @()
foreach ($dll in (Get-ChildItem $staging -Filter '*_plugin.dll' -File)) {
  if ($expectedPlugins -notcontains $dll.Name) { $stale += $dll }
}
foreach ($dll in $stale) {
  Write-Detail "dropping stale plugin: $($dll.Name)"
  Remove-Item $dll.FullName -Force
}

# Flutter's asset bundling never prunes entries of packages that were removed
# from pubspec.yaml - a freshly built bundle can still carry
# packages/<removed-plugin>/ trees. Drop those too.
$packagesDir = Join-Path $staging 'data\flutter_assets\packages'
if (Test-Path $packagesDir) {
  foreach ($dir in (Get-ChildItem $packagesDir -Directory)) {
    if ($expectedPlugins -notcontains "$($dir.Name)_plugin.dll") {
      Write-Detail "dropping stale asset package: $($dir.Name)"
      Remove-Item $dir.FullName -Recurse -Force
    }
  }
}

# Runtime artefacts that must never ship: the renderer's log and any
# PET_LIVE2D_DUMP bitmaps (see doc/live2d-renderer-notes.md section 5).
foreach ($junk in (Get-ChildItem $staging -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '*.log' -or $_.Name -like 'l2d_dump_*.bmp' })) {
  Write-Detail "dropping runtime artefact: $($junk.Name)"
  Remove-Item $junk.FullName -Force
}

# ---- 4. self-contained runtime + licenses ----------------------------------
Write-Step 'runtime + licenses'

# App-local MSVC runtime (see Find-VcRuntimeDir). Without it the package only
# starts where the VC++ 2015-2022 x64 Redistributable is already installed.
$crtDir = Find-VcRuntimeDir
if ($crtDir) {
  $crtDlls = @(Get-ChildItem $crtDir -Filter '*.dll' -File)
  foreach ($dll in $crtDlls) { Copy-Item $dll.FullName $staging -Force }
  Write-Detail "app-local CRT from $crtDir ($($crtDlls.Count) dll)"
} else {
  Write-Warning ('VC++ runtime DLLs not found on this machine: the package will only run where the ' +
    'VC++ 2015-2022 x64 Redistributable is installed. Install the MSVC build tools / redist to bundle it app-local.')
}

# License + third-party notices travel with the shipped binaries.
foreach ($doc in @('LICENSE', 'NOTICES')) {
  $src = Join-Path $repoRoot $doc
  if (Test-Path $src) { Copy-Item $src $staging -Force; Write-Detail "license: $doc" }
  else { Write-Warning "$doc not found at the repo root" }
}

# The Cubism Core is statically linked into pet_live2d_plugin.dll, so the SDK's
# own license must ship with the package.
$coreLicense = Join-Path $repoRoot 'third_party\live2d\windows\LICENSE.core.md'
if (Test-Path $coreLicense) {
  Copy-Item $coreLicense (Join-Path $staging 'Live2D-Cubism-Core-LICENSE.md') -Force
  Write-Detail 'license: Live2D-Cubism-Core-LICENSE.md'
} else {
  Write-Warning ('third_party/live2d/windows/LICENSE.core.md not found (SDK not fetched?) - ' +
    'the Live2D license text is missing from the package.')
}

# Empty directories are noise in a distributable, and Flutter's bundling leaves
# them behind for assets that no longer exist. Remove bottom-up (emptying a
# directory can empty its parent), counting hidden files so a directory that
# only holds a dotfile is not deleted.
$removedDirs = 0
do {
  $empties = @(Get-ChildItem $staging -Recurse -Directory | Where-Object {
      @(Get-ChildItem $_.FullName -Force).Count -eq 0
    })
  foreach ($dir in $empties) {
    Remove-Item $dir.FullName -Force
    $removedDirs++
  }
} while ($empties.Count -gt 0)
if ($removedDirs -gt 0) { Write-Detail "dropping $removedDirs empty director$(if ($removedDirs -eq 1) { 'y' } else { 'ies' })" }

# ---- 5. zip ----------------------------------------------------------------
Write-Step 'zipping'
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
$baseName = "DesktopPet-$version-windows-x64"
$zipPath = Join-Path $distDir "$baseName.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zipPath -CompressionLevel Optimal

$zip = Get-Item $zipPath
$raw = (Get-ChildItem $staging -Recurse -File | Measure-Object Length -Sum).Sum
$sha = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("    {0}`n    {1} MB packed from {2} MB ({3}%)`n    sha256 {4}" -f `
    $zipPath, [math]::Round($zip.Length / 1MB, 1), [math]::Round($raw / 1MB, 1), `
    [math]::Round(100 * $zip.Length / $raw), $sha)

# ---- 6. optional installer -------------------------------------------------
$iscc = Get-Command iscc -ErrorAction SilentlyContinue
if (-not $iscc) {
  $guess = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
  if (Test-Path $guess) { $iscc = Get-Item $guess }
}

if ($iscc) {
  Write-Step 'building installer (Inno Setup)'
  $issPath = Join-Path $distDir "$baseName.iss"
  $setupPath = Join-Path $distDir "$baseName-setup"
  $iss = @"
[Setup]
AppName=Desktop Pet
AppVersion=$version
AppPublisher=Desktop Pet
DefaultDirName={autopf}\Desktop Pet
DefaultGroupName=Desktop Pet
OutputDir=$distDir
OutputBaseFilename=$baseName-setup
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes

[Files]
Source: "$staging\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Desktop Pet"; Filename: "{app}\desktop_pet.exe"
Name: "{autodesktop}\Desktop Pet"; Filename: "{app}\desktop_pet.exe"
"@
  [System.IO.File]::WriteAllText($issPath, $iss, (New-Object System.Text.UTF8Encoding($false)))
  & $iscc.Source $issPath | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "ISCC failed (exit $LASTEXITCODE)" }
  $setup = Get-Item "$setupPath.exe"
  Write-Host ("    {0}`n    {1} MB" -f $setup.FullName, [math]::Round($setup.Length / 1MB, 1))
} else {
  Write-Detail 'Inno Setup not found - zip only (install it to also get a setup.exe)'
}

if (-not $KeepStaging) { Remove-Item $staging -Recurse -Force }
else { Write-Detail "staging kept at $staging" }

Write-Step 'done'
