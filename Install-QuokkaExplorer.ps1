[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ClamScanPath,
    [string]$DatabasePath,
    [string]$ViewerPath
)
$ErrorActionPreference = 'Stop'
try {
    $launcher = Join-Path $PSScriptRoot 'Invoke-QuokkaExplorer.ps1'
    foreach ($file in @($launcher, (Join-Path $PSScriptRoot 'Scan-Quokka.ps1'), (Join-Path $PSScriptRoot 'Open-QuokkaIsolation.ps1'))) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Required script missing: $file" }
    }
    foreach ($entry in @(@('ClamScanPath', $ClamScanPath, 'Leaf'), @('DatabasePath', $DatabasePath, 'Container'), @('ViewerPath', $ViewerPath, 'Leaf'))) {
        if ($entry[1] -and -not (Test-Path -LiteralPath $entry[1] -PathType $entry[2])) { throw "$($entry[0]) does not exist: $($entry[1])" }
    }
    $powershell = Join-Path $PSHOME 'powershell.exe'
    $base = 'HKCU:\Software\Classes\SystemFileAssociations'
    $settingsPath = 'HKCU:\Software\ClickQuokka'
    if ($PSCmdlet.ShouldProcess('Current user PDF and TXT context menus', 'Install Click Quokka actions')) {
        if (-not (Test-Path -LiteralPath $settingsPath)) { New-Item -Path $settingsPath -Force | Out-Null }
        foreach ($name in @('ClamScanPath', 'DatabasePath', 'ViewerPath')) {
            $value = Get-Variable -Name $name -ValueOnly
            if ($value) { Set-ItemProperty -LiteralPath $settingsPath -Name $name -Value (Get-Item -LiteralPath $value).FullName }
        }
        foreach ($verb in @(@('.pdf', 'ClickQuokka.Scan', 'Scan with Click Quokka', 'Scan'), @('.pdf', 'ClickQuokka.Isolation', 'Open in Click Quokka Isolation', 'Isolation'), @('.txt', 'ClickQuokka.Scan', 'Scan with Click Quokka', 'Scan'))) {
            $key = Join-Path (Join-Path $base ($verb[0] + '\shell')) $verb[1]
            New-Item -Path $key -Force | Out-Null
            Set-Item -LiteralPath $key -Value $verb[2]
            New-ItemProperty -LiteralPath $key -Name 'MultiSelectModel' -Value 'Single' -PropertyType String -Force | Out-Null
            $commandKey = Join-Path $key 'command'
            New-Item -Path $commandKey -Force | Out-Null
            $windowOption = if ($verb[3] -eq 'Scan') { ' -WindowStyle Hidden' } else { '' }
            $command = '"{0}" -NoProfile{3} -ExecutionPolicy Bypass -File "{1}" -Action {2} -Path "%1"' -f $powershell, $launcher, $verb[3], $windowOption
            Set-Item -LiteralPath $commandKey -Value $command
        }
        Write-Host 'Click Quokka actions installed for this user. Right-click a PDF or TXT file and choose Show more options.'
    }
} catch { Write-Error "Installation failed: $($_.Exception.Message)"; exit 1 }
