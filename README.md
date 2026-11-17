# Click Quokka

Work in progress: the scanner CLI is implemented, but isolated viewing and Explorer integration are not yet implemented.

## Scanner

Install ClamAV for Windows and update its signature database using the ClamAV instructions. From Windows PowerShell:

```powershell
.\Scan-Quokka.ps1 -Path 'C:\Downloads\example.pdf' -ClamScanPath 'C:\Program Files\ClamAV\clamscan.exe'
```

Use `-DatabasePath` if your signature database is not in ClamAV's default location, and `-TimeoutSeconds` to change the default 120-second timeout. The command accepts non-PDF files for EICAR testing. Exit codes are 0 for no threats detected, 1 for a threat, and 2 for failure. It does not request removal, quarantine, or opening of the selected file. A clean result is not a guarantee that a file is safe.

The scanner runs as a direct child process rather than through a command shell, and checks the scan summary before reporting a clean result. This keeps filenames as data and prevents a skipped scan from being reported as clean.

## Verification status

- Passed: missing input and missing scanner produce `Scan failed` in Windows PowerShell 5.1.
- Not run: real ClamAV clean PDF, EICAR, timeout, unreadable file, Unicode and spaces. ClamAV was not found in the environment during initial inspection.
- Not implemented: Windows Sandbox viewer, session cleanup, Explorer integration, install/uninstall scripts, and their runtime checks.
