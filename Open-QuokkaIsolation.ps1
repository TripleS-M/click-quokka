[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ViewerPath
)
$ErrorActionPreference = 'Stop'
try {
    $file = Get-Item -LiteralPath $Path -Force
    if ($file.PSProvider.Name -ne 'FileSystem' -or $file.PSIsContainer -or $file.FullName -notmatch '^[A-Za-z]:\\' -or $file.FullName.Substring(2).Contains(':') -or $file.Extension -ine '.pdf') {
        throw 'Select a local PDF file.'
    }
    $stream = [IO.File]::Open($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $header = New-Object byte[] 5
        if ($stream.Read($header, 0, 5) -ne 5 -or [Text.Encoding]::ASCII.GetString($header) -ne '%PDF-') { throw 'The file does not have a PDF header.' }
    } finally { $stream.Dispose() }
    $viewer = Get-Item -LiteralPath $ViewerPath -Force
    if ($viewer.PSProvider.Name -ne 'FileSystem' -or $viewer.PSIsContainer -or $viewer.Extension -ine '.exe' -or $viewer.FullName -notmatch '^[A-Za-z]:\\') { throw 'ViewerPath must point to a local portable SumatraPDF executable.' }
    $sandbox = Get-Command WindowsSandbox.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sandbox) { throw 'Windows Sandbox is unavailable. Enable the Windows Sandbox optional feature and install the Sandbox app, then try again.' }
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
    $id = [guid]::NewGuid().ToString()
    $root = Join-Path $env:LOCALAPPDATA 'ClickQuokka\Sessions'
    $session = Join-Path $root $id
    $payload = Join-Path $session 'payload'
    New-Item -ItemType Directory -Path $payload -Force | Out-Null
    @{ Id = $id; Boot = $boot; CreatedUtc = [DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'session.json') -Encoding UTF8
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $payload 'document.pdf')
    Copy-Item -LiteralPath $viewer.FullName -Destination (Join-Path $payload 'viewer.exe')
    $bootstrap = @'
$ErrorActionPreference = 'Stop'
try {
    $local = Join-Path $env:TEMP 'ClickQuokkaViewer'
    New-Item -ItemType Directory -Force -Path $local | Out-Null
    Copy-Item -LiteralPath 'C:\ClickQuokka\viewer.exe' -Destination (Join-Path $local 'viewer.exe')
    $viewer = Start-Process -FilePath (Join-Path $local 'viewer.exe') -ArgumentList @('-appdata', 'C:\Users\WDAGUtilityAccount\AppData\Local\ClickQuokka', 'C:\ClickQuokka\document.pdf') -PassThru -Wait
    if ($viewer.ExitCode -ne 0) { throw "Viewer exited with code $($viewer.ExitCode)." }
} catch {
    Write-Host "Click Quokka viewer failed: $($_.Exception.Message)"
    Write-Host 'Press Enter to close this window.'
    [void][Console]::ReadLine()
}
'@
    Set-Content -LiteralPath (Join-Path $payload 'start.ps1') -Value $bootstrap -Encoding UTF8
    $xml = New-Object System.Xml.XmlDocument
    $configuration = $xml.CreateElement('Configuration'); [void]$xml.AppendChild($configuration)
    function Add-Element($parent, [string]$name, [string]$value) {
        $element = $xml.CreateElement($name); if ($value) { $element.InnerText = $value }; [void]$parent.AppendChild($element); return $element
    }
    foreach ($name in @('VGpu', 'Networking', 'ClipboardRedirection', 'AudioInput', 'VideoInput', 'PrinterRedirection')) { [void](Add-Element $configuration $name 'Disable') }
    $folders = Add-Element $configuration 'MappedFolders' ''
    $folder = Add-Element $folders 'MappedFolder' ''
    [void](Add-Element $folder 'HostFolder' $payload)
    [void](Add-Element $folder 'SandboxFolder' 'C:\ClickQuokka')
    [void](Add-Element $folder 'ReadOnly' 'true')
    $logon = Add-Element $configuration 'LogonCommand' ''
    [void](Add-Element $logon 'Command' 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ClickQuokka\start.ps1')
    $wsb = Join-Path $session 'session.wsb'
    $xml.Save($wsb)
    Start-Process -FilePath $sandbox.Source -ArgumentList ('"' + $wsb + '"') -ErrorAction Stop | Out-Null
    Write-Host "Sandbox launch requested. Session: $id"
    Write-Host 'Guest startup and PDF rendering must be verified in the Sandbox window.'
} catch {
    Write-Host "Isolation failed: $($_.Exception.Message)"
    if ($session) { Write-Host "Staging retained for safe cleanup: $session" }
    exit 1
}
