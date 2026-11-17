# Click Quokka

Work in progress: scanner, isolated viewing, and Explorer actions are implemented. See the verification status below for checks still needed.

## Scanner

Install ClamAV for Windows and update its signature database using the ClamAV instructions. From Windows PowerShell:

```powershell
.\Scan-Quokka.ps1 -Path 'C:\Downloads\example.pdf' -ClamScanPath 'C:\Program Files\ClamAV\clamscan.exe'
```

Use `-DatabasePath` if your signature database is not in ClamAV's default location, and `-TimeoutSeconds` to change the default 120-second timeout. The command accepts non-PDF files for EICAR testing. Exit codes are 0 for no threats detected, 1 for a threat, and 2 for failure. It does not request removal, quarantine, or opening of the selected file. A clean result is not a guarantee that a file is safe.

If `.clamav\database` exists in the project, the scanner uses it automatically; `-DatabasePath` takes precedence. To set up and update a project-local database, from the project folder run:

```powershell
New-Item -ItemType Directory -Force .\.clamav\database | Out-Null
Set-Content -LiteralPath .\.clamav\freshclam.conf -Value 'DatabaseMirror database.clamav.net' -Encoding ASCII
& 'C:\Program Files\ClamAV\freshclam.exe' --config-file="$(Resolve-Path .\.clamav\freshclam.conf)" --datadir="$(Resolve-Path .\.clamav\database)"
```

The scanner runs as a direct child process rather than through a command shell, and checks the scan summary before reporting a clean result. This keeps filenames as data and prevents a skipped scan from being reported as clean.

## Isolated viewing

Windows 11 Pro, Enterprise, or Education, hardware virtualization, and the Windows Sandbox optional feature are required. Enable Windows Sandbox using Windows Features, restart if prompted, and install/update the Windows Sandbox app if required by your Windows version. Download a trusted portable SumatraPDF executable from [the official site](https://www.sumatrapdfreader.org/free-pdf-reader.html). The viewer must be a self-contained portable executable, not an installer requiring companion files.

```powershell
.\Open-QuokkaIsolation.ps1 -Path 'C:\Downloads\example.pdf' -ViewerPath 'C:\Tools\SumatraPDF.exe'
```

The command checks the PDF extension and header, copies it to a unique staging directory as `document.pdf`, and starts Sandbox with that one directory mapped read-only. The portable viewer and a fixed bootstrap script are also staged there. Networking and clipboard sharing are disabled in the configuration. The viewer is copied into writable guest storage so it can extract its own components. Opening the Sandbox window does not prove that the document rendered; inspect the guest window. A bootstrap failure remains visible inside the guest.

Staged copies remain on disk after a session. Close Sandbox and **restart Windows** before cleaning up; a normal shutdown with Fast Startup may not count as a restart. This conservative rule avoids assuming that a launcher exit means the guest closed. Replace the GUID with the session ID shown at launch:

```powershell
.\Remove-QuokkaSession.ps1 -SessionId '00000000-0000-0000-0000-000000000000' -WhatIf
.\Remove-QuokkaSession.ps1 -SessionId '00000000-0000-0000-0000-000000000000'
```

Sessions are stored under `%LOCALAPPDATA%\ClickQuokka\Sessions`. Cleanup refuses the current boot and refuses session directories containing reparse points. It does not remove the original PDF. If staging fails before metadata is written, inspect that folder manually after a restart.

## Explorer actions

From Windows PowerShell in the project folder, register the actions for your account (adjust the paths to your installations):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-QuokkaExplorer.ps1 -ClamScanPath 'C:\Program Files\ClamAV\clamscan.exe' -ViewerPath 'C:\Tools\SumatraPDF.exe'
```

An optional `-DatabasePath` sets a specific signature directory. Re-run the installer to update a configured path after moving a dependency or this project. The actions refer to scripts in this folder, so keep the folder in place. Omitting a setting preserves its existing value; scanning can be used without a viewer.

Right-click one PDF in File Explorer, select **Show more options**, and choose **Scan with Click Quokka** or **Open in Click Quokka Isolation**. Each action is independent and leaves a console open for its result; press Enter to close it. Scanning never opens the PDF.

To remove the two menu entries for your account:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-QuokkaExplorer.ps1
```

Uninstall preserves the saved paths, database, and staged sessions. Neither script changes the default PDF association. Both support `-WhatIf`.

## Verification status

- Passed: missing input and missing scanner produce `Scan failed` in Windows PowerShell 5.1.
- Passed: ClamAV 1.5.4 scanned the project README with a downloaded signature database and returned `No threats detected`.
- Passed: isolation rejects a missing file and a non-PDF, and reports unavailable Sandbox for a PDF-shaped test file; both new scripts parse in Windows PowerShell 5.1.
- Not run: real ClamAV clean PDF, EICAR, timeout, unreadable file, Unicode and spaces. ClamAV was not found in the environment during initial inspection.
- Not run: real Sandbox launch, offline viewer rendering, read-only mapped-folder writes, networking and clipboard restrictions, and fresh-session behavior. Sandbox and the portable viewer were not found during initial inspection.
- Passed: both per-user PDF verb names, commands, and single-selection settings were verified in the registry.
- Not run: interactive Explorer selection and uninstall/reinstall verification.
