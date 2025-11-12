param(
    [string]$Arch = "x64"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$Pubspec = Join-Path $RepoRoot "pubspec.yaml"
$Artifacts = Join-Path $RepoRoot "artifacts"

$versionLine = (Select-String -Path $Pubspec -Pattern '^version:' | Select-Object -First 1).Line
if (-not $versionLine) {
    Write-Error "未找到version字段"
    exit 1
}
$raw = ($versionLine -split ':')[1].Trim()
$semver = ($raw -split '\+')[0]
$artifactName = "windows-$Arch-$semver"
$targetDir = Join-Path $RepoRoot "build/windows/$Arch/runner/Release"
$outputPath = Join-Path $Artifacts ("{0}.zip" -f $artifactName)

if (-not (Test-Path $targetDir)) {
    Write-Error "未找到Windows构建产物: $targetDir"
    exit 1
}

[void][IO.Directory]::CreateDirectory($Artifacts)
if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
}

$sourcePattern = Join-Path $targetDir '*'
Compress-Archive -Path $sourcePattern -DestinationPath $outputPath -Force

Write-Host "生成: $outputPath"
if ($Env:GITHUB_OUTPUT) {
    "artifact-name=$artifactName" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
    "artifact-path=$outputPath" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
}
