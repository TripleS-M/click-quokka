[CmdletBinding(SupportsShouldProcess = $true)]
param()
$ErrorActionPreference = 'Stop'
try {
    $base = 'HKCU:\Software\Classes\SystemFileAssociations\.pdf\shell'
    foreach ($name in @('ClickQuokka.Scan', 'ClickQuokka.Isolation')) {
        $key = Join-Path $base $name
        if ((Test-Path -LiteralPath $key) -and $PSCmdlet.ShouldProcess($key, 'Remove Click Quokka action')) {
            Remove-Item -LiteralPath $key -Recurse -Force
        }
    }
    if (-not $WhatIfPreference) { Write-Host 'Click Quokka Explorer actions removed. Settings and staged sessions were preserved.' }
} catch { Write-Error "Uninstall failed: $($_.Exception.Message)"; exit 1 }
