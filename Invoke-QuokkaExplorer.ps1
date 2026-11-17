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
    if ($Action -eq 'Scan') { $scanOutput = (& $powershell @arguments 2>&1 | Out-String).Trim() }
    else { & $powershell @arguments }
    $result = $LASTEXITCODE
    if ($null -eq $result) { $result = 1 }
} catch {
    $scanOutput = "Scan failed: $($_.Exception.Message)"
    if ($Action -ne 'Scan') { Write-Host $scanOutput }
    $result = 1
}
if ($Action -eq 'Scan') {
    Add-Type -AssemblyName System.Windows.Forms
    if ($result -eq 0 -and $scanOutput -match '^No threats detected') { $message = 'No threats detected'; $icon = 'Information' }
    elseif ($result -eq 1 -and $scanOutput -match '^Threat detected') { $message = $scanOutput; $icon = 'Warning' }
    else { $message = if ($scanOutput) { $scanOutput } else { 'Scan failed: no result was returned.' }; $icon = 'Error' }
    [void][System.Windows.Forms.MessageBox]::Show($message, 'Click Quokka scan', 'OK', $icon)
} else {
    Write-Host ''
    [void](Read-Host 'Press Enter to close')
}
exit $result
