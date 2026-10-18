param()
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$projectPath = Split-Path -Parent $PSScriptRoot
$engineRoot = Join-Path $projectPath 'engines\katago'
$manifest = Get-Content -LiteralPath (Join-Path $engineRoot 'source.json') -Raw | ConvertFrom-Json
$downloads = Join-Path $engineRoot 'downloads'
$runtime = Join-Path $engineRoot 'runtime'
New-Item -ItemType Directory -Force $downloads, $runtime | Out-Null
# Keep large downloaded assets outside both Git and Godot's resource importer.
Set-Content -LiteralPath (Join-Path $downloads '.gdignore') -Value ''
Set-Content -LiteralPath (Join-Path $runtime '.gdignore') -Value ''

function Get-VerifiedFile([string]$Url, [string]$Destination, [string]$ExpectedHash) {
    if ((Test-Path -LiteralPath $Destination) -and (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant() -eq $ExpectedHash) {
        Write-Host ('Verified: ' + [IO.Path]::GetFileName($Destination))
        return
    }
    $partial = $Destination + '.partial'
    Write-Host ('Downloading from official source: ' + $Url)
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $partial -TimeoutSec 1200
    if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedHash) {
        throw 'SHA-256 mismatch. Download was not installed. Retry later or check the official release.'
    }
    Move-Item -LiteralPath $partial -Destination $Destination -Force
}

$archive = Join-Path $downloads 'opencl.zip'
Get-VerifiedFile $manifest.engine_url $archive $manifest.engine_sha256
Get-VerifiedFile $manifest.model_url (Join-Path $runtime 'model.bin.gz') $manifest.model_sha256
Expand-Archive -LiteralPath $archive -DestinationPath $runtime -Force
Write-Host 'KataGo installed. Start Quiet Go and select KataGo in game settings.'
Write-Host 'The first AI request tunes your GPU and can take several minutes. Subsequent games work offline.'
