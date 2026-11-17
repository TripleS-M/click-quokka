[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param([Parameter(Mandatory = $true)][guid]$SessionId)
$ErrorActionPreference = 'Stop'
try {
    $root = Join-Path $env:LOCALAPPDATA 'ClickQuokka\Sessions'
    $session = Join-Path $root $SessionId.ToString()
    $rootItem = Get-Item -LiteralPath $root -Force
    $sessionItem = Get-Item -LiteralPath $session -Force
    if (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or ($sessionItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Reparse points are not allowed.' }
    $metadataFile = Get-Item -LiteralPath (Join-Path $session 'session.json') -Force
    if ($metadataFile.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Session metadata must not be a reparse point.' }
    $metadata = Get-Content -LiteralPath $metadataFile.FullName -Raw | ConvertFrom-Json
    if ($metadata.Id -ne $SessionId.ToString()) { throw 'Session metadata does not match the requested ID.' }
    # Import explicitly so -WhatIf does not report the module's alias setup as pending operations.
    $savedWhatIf = $WhatIfPreference; $WhatIfPreference = $false
    Import-Module CimCmdlets
    $WhatIfPreference = $savedWhatIf
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
    $createdBoot = [DateTime]::Parse($metadata.Boot).ToUniversalTime()
    $created = [DateTime]::Parse($metadata.CreatedUtc).ToUniversalTime()
    # Require the current boot to start after the session was created, not merely differ from the recorded boot time.
    if ($boot -le $createdBoot -or $boot -le $created) { throw 'Cleanup is deferred until Windows has restarted since this session was created.' }
    $reparse = Get-ChildItem -LiteralPath $session -Force -Recurse | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } | Select-Object -First 1
    if ($reparse) { throw 'Session contains a reparse point; cleanup refused.' }
    if ($PSCmdlet.ShouldProcess($session, 'Remove staged session')) { Remove-Item -LiteralPath $session -Recurse -Force; Write-Host 'Session removed.' }
} catch { Write-Error "Cleanup failed: $($_.Exception.Message)"; exit 1 }
