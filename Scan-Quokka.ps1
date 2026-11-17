param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Path,
    [string]$ClamScanPath = 'clamscan.exe',
    [string]$DatabasePath,
    [ValidateRange(1, 86400)][int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
try {
    if (-not $PSBoundParameters.ContainsKey('DatabasePath')) {
        $projectDatabase = Join-Path $PSScriptRoot '.clamav\database'
        if (Test-Path -LiteralPath $projectDatabase -PathType Container) { $DatabasePath = $projectDatabase }
    }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSProvider.Name -ne 'FileSystem' -or $item.PSIsContainer -or $item.FullName.StartsWith('\\')) {
        throw 'Select a local regular file.'
    }
    if ($item.FullName.Substring(2).Contains(':')) { throw 'Alternate data streams are not supported.' }
    $stream = [System.IO.File]::Open($item.FullName, 'Open', 'Read', 'ReadWrite')
    $stream.Dispose()
    $scanner = Get-Command $ClamScanPath -CommandType Application -ErrorAction Stop | Select-Object -First 1
    # Quote for the Windows C runtime argument parser, without involving a shell.
    function Quote-Argument([string]$value) {
        return '"' + [regex]::Replace($value, '(\\*)"', '$1$1\"').TrimEnd('\') + ('\' * ([regex]::Match($value, '\\*$').Length * 2)) + '"'
    }
    # Without this, ClamAV silently skips files over its size limits and reports them as OK.
    $arguments = @('--stdout', '--alert-exceeds-max=yes')
    if ($DatabasePath) { $arguments += ('--database=' + (Quote-Argument $DatabasePath)) }
    $arguments += '--'
    $arguments += (Quote-Argument $item.FullName)
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $scanner.Source
    $info.Arguments = $arguments -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    if (-not $process.Start()) { throw 'Scanner did not start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        $process.WaitForExit()
        throw 'Scanner timed out.'
    }
    $output = $stdout.GetAwaiter().GetResult()
    $errors = $stderr.GetAwaiter().GetResult()
    if ($output -match 'Heuristics\.Limits\.Exceeded') { throw 'The file exceeds scanner limits and was not fully scanned.' }
    if ($process.ExitCode -eq 1) {
        $signature = [regex]::Match($output, '(?m): ([^\r\n]+) FOUND\s*$')
        if ($signature.Success) { Write-Host ("Threat detected: " + $signature.Groups[1].Value) }
        else { Write-Host 'Threat detected' }
        exit 1
    }
    if ($process.ExitCode -ne 0 -or $output -notmatch '(?m)^Scanned files:\s*1\s*$' -or $output -match '(?m)^Total errors:\s*[1-9]') {
        throw ("Scanner did not complete a clean scan. " + $errors + ' ' + $output)
    }
    Write-Host 'No threats detected'
    exit 0
} catch {
    Write-Host ("Scan failed: " + $_.Exception.Message)
    exit 2
}
