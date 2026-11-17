[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('Scan', 'Isolation')][string]$Action,
    [Parameter(Mandatory = $true)][string]$Path
)
$ErrorActionPreference = 'Stop'
try {
    $extension = [IO.Path]::GetExtension($Path)
    if ($Action -eq 'Scan' -and $extension -notin @('.pdf', '.txt')) { throw 'Explorer scanning accepts PDF and TXT files only.' }
    if ($Action -eq 'Isolation' -and $extension -ine '.pdf') { throw 'Isolated viewing accepts PDF files only.' }
    $settings = Get-ItemProperty -LiteralPath 'HKCU:\Software\ClickQuokka' -ErrorAction SilentlyContinue
    $powershell = Join-Path $PSHOME 'powershell.exe'
    if ($Action -eq 'Scan') {
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'Scan-Quokka.ps1'), '-Path', $Path)
        if ($settings -and $settings.ClamScanPath) { $arguments += @('-ClamScanPath', $settings.ClamScanPath) }
        if ($settings -and $settings.DatabasePath) { $arguments += @('-DatabasePath', $settings.DatabasePath) }
    } else {
        if (-not $settings -or -not $settings.ViewerPath) { throw 'Portable PDF viewer is not configured. Re-run Install-QuokkaExplorer.ps1 with -ViewerPath.' }
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'Open-QuokkaIsolation.ps1'), '-Path', $Path, '-ViewerPath', $settings.ViewerPath)
    }
    & $powershell @arguments
    $result = $LASTEXITCODE
    if ($null -eq $result) { $result = 1 }
} catch {
    Write-Host "Click Quokka failed: $($_.Exception.Message)"
    $result = 1
}
Write-Host ''
[void](Read-Host 'Press Enter to close')
exit $result
