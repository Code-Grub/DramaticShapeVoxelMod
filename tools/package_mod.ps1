param(
  [string]$Output = ""
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
function Relative-Path([string]$FullName) {
  return $FullName.Substring($repo.Length + 1).Replace('\', '/')
}
if (-not $Output) {
  $Output = Join-Path (Split-Path $repo -Parent) "DramaticShapeVoxelMod-battle-art.zip"
}
$Output = [System.IO.Path]::GetFullPath($Output)

$source = @()
foreach ($dir in @('data', 'lib')) {
  $source += Get-ChildItem -LiteralPath (Join-Path $repo $dir) -Recurse -File |
    ForEach-Object {
      Relative-Path $_.FullName
    }
}
$source += @('CHANGELOG.md', 'main.lua', 'manifest.json', 'mod.card', 'README.md')
$contracts = @(Get-ChildItem -LiteralPath (Join-Path $repo 'assets\battle') `
  -Recurse -File -Filter 'README.md' | ForEach-Object {
    Relative-Path $_.FullName
  })

# These files are deliberately ignored by Git, but a local test build should
# include them. This bridges a clean public branch and private BYO artwork.
$localArt = @(Get-ChildItem -LiteralPath (Join-Path $repo 'assets\battle') `
  -Recurse -File -Filter '*.png' -ErrorAction SilentlyContinue | ForEach-Object {
    Relative-Path $_.FullName
  })
$files = @($source + $contracts + $localArt | Sort-Object -Unique)
if (-not $files.Count) { throw "no package files found" }

if (Test-Path -LiteralPath $Output) { Remove-Item -LiteralPath $Output -Force }
Push-Location $repo
try {
  & tar -a -cf $Output @files
  if ($LASTEXITCODE -ne 0) { throw "tar failed: $LASTEXITCODE" }
} finally {
  Pop-Location
}

$entries = @(tar -tf $Output)
[PSCustomObject]@{
  Path = $Output
  Entries = $entries.Count
  LocalPngs = $localArt.Count
  Bytes = (Get-Item -LiteralPath $Output).Length
  SHA256 = (Get-FileHash -LiteralPath $Output -Algorithm SHA256).Hash
}
