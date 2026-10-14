param([switch]$Render)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$enginePath = 'D:\godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
$oldAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $projectPath '.runtime'
    foreach ($suite in @('rules','puzzles','ui')) {
        $log = Join-Path $projectPath ('evidence\' + $suite + '.log')
        & $enginePath --headless --audio-driver Dummy --path $projectPath --script ('res://tests/test_' + $suite + '.gd') --log-file $log -- --test-mode
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Parse Error|FAIL:' -Quiet) -or -not (Select-String -LiteralPath $log -Pattern '0 failures' -Quiet)) { throw "Failed: $suite" }
    }
    if ($Render) {
        $log = Join-Path $projectPath 'evidence\render.log'
        $arguments = @('--path', ('"' + $projectPath + '"'), '--audio-driver','Dummy','--script','res://tests/test_ui.gd','--log-file',('"' + $log + '"'),'--','--test-mode','--render')
        $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
        if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|SHADER ERROR|FAIL UI' -Quiet) -or -not (Select-String -LiteralPath $log -Pattern '0 failures' -Quiet)) { throw 'Rendering verification failed' }
    }
    Write-Host 'Quiet Go verification passed.'
} finally {
    $env:APPDATA = $oldAppData
}
