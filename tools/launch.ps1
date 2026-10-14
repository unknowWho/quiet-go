param([switch]$Editor,[switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$enginePath = $env:GODOT_EXE
if (-not $enginePath -or -not (Test-Path -LiteralPath $enginePath)) {
    $enginePath = 'D:\godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $enginePath)) {
    $engineCommand = Get-Command godot, godot.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($engineCommand) { $enginePath = $engineCommand.Source }
}
if (-not $enginePath -or -not (Test-Path -LiteralPath $enginePath)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('Install Godot 4.7.1 and open project.godot, or set GODOT_EXE.','Quiet Go')
    exit 1
}
$log = Join-Path $projectPath 'evidence\launcher-import.log'
if (-not (Test-Path -LiteralPath (Join-Path $projectPath '.godot\imported'))) {
    & $enginePath --headless --path $projectPath --editor --import --quit --log-file $log *> $null
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Parse Error' -Quiet)) { exit 1 }
}
if ($CheckOnly) {
    & $enginePath --headless --path $projectPath --quit-after 8 --log-file (Join-Path $projectPath 'evidence\launcher-check.log') -- --test-mode
    exit $LASTEXITCODE
}
$guiPath = $enginePath -replace '_console\.exe$', '.exe'
if (-not (Test-Path -LiteralPath $guiPath)) { $guiPath = $enginePath }
$arguments = @('--path', ('"' + $projectPath + '"'))
if ($Editor) { $arguments += '--editor' }
# Play/Edit were explicitly selected by the player; these are interactive windows.
Start-Process -FilePath $guiPath -ArgumentList $arguments -WorkingDirectory $projectPath -WindowStyle Normal
