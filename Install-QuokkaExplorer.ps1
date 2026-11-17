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
    $base = 'HKCU:\Software\Classes\SystemFileAssociations\.pdf\shell'
    $settingsPath = 'HKCU:\Software\ClickQuokka'
    if ($PSCmdlet.ShouldProcess('Current user PDF context menu', 'Install Click Quokka actions')) {
        New-Item -Path $settingsPath -Force | Out-Null
        foreach ($name in @('ClamScanPath', 'DatabasePath', 'ViewerPath')) {
            $value = Get-Variable -Name $name -ValueOnly
            if ($value) { Set-ItemProperty -LiteralPath $settingsPath -Name $name -Value (Get-Item -LiteralPath $value).FullName }
        }
        foreach ($verb in @(@('ClickQuokka.Scan', 'Scan with Click Quokka', 'Scan'), @('ClickQuokka.Isolation', 'Open in Click Quokka Isolation', 'Isolation'))) {
            $key = Join-Path $base $verb[0]
            New-Item -Path $key -Force | Out-Null
            Set-Item -LiteralPath $key -Value $verb[1]
            New-ItemProperty -LiteralPath $key -Name 'MultiSelectModel' -Value 'Single' -PropertyType String -Force | Out-Null
            $commandKey = Join-Path $key 'command'
            New-Item -Path $commandKey -Force | Out-Null
            $command = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" -Action {2} -Path "%1"' -f $powershell, $launcher, $verb[2]
            Set-Item -LiteralPath $commandKey -Value $command
        }
        Write-Host 'Click Quokka actions installed for this user. Right-click a PDF and choose Show more options.'
    }
} catch { Write-Error "Installation failed: $($_.Exception.Message)"; exit 1 }
