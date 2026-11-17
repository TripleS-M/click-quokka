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

The scanner runs as a direct child process rather than through a command shell, and checks the scan summary before reporting a clean result. This keeps filenames as data and prevents a skipped scan from being reported as clean. Files exceeding ClamAV's size or scan limits (100 MB per file by default) are reported as `Scan failed` rather than clean.

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

Right-click one PDF or TXT file in File Explorer, select **Show more options**, and choose **Scan with Click Quokka**. The scan result appears in a popup, including failures and available threat names. PDFs also offer **Open in Click Quokka Isolation**, which reports its result in a console. Scanning never opens the file.

To remove the two menu entries for your account:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-QuokkaExplorer.ps1
```

Uninstall preserves the saved paths, database, and staged sessions. Neither script changes default file associations. Both support `-WhatIf`.

## Verification status

The following records checks performed on Windows PowerShell 5.1 with ClamAV 1.5.4. Results from simulated signatures are identified separately from EICAR.

| Check | Status | Evidence or remaining work |
| --- | --- | --- |
| Clean PDF | Passed | Real ClamAV returned `No threats detected` for `examples\harmless.pdf` and another PDF; the latter's SHA-256 hash was unchanged. |
| Threat result | Passed with custom signature | Real ClamAV and Click Quokka returned `Threat detected: ClickQuokka.Test.UNOFFICIAL` for a harmless text file and a temporary custom database. |
| EICAR | Passed | An EICAR `.txt` returned `Threat detected: Eicar-Test-Signature` (exit 1), both from the command line and in the Explorer popup. Defender did not intercept it on this machine. |
| Timeout, missing input, missing scanner | Passed | Reported `Scan failed`; timeout returned exit code 2. |
| Unicode and spaces | Passed | PDFs with Unicode characters, spaces, `[ ]` and `$` in their names returned `No threats detected`. |
| Unreadable file | Passed | A file held open with no sharing and a file with a read-deny ACL each returned `Scan failed` (exit 2). |
| Oversized file | Passed | A 120 MB PDF (above ClamAV's 100 MB default limit) previously reported clean without being scanned; it now returns `Scan failed: The file exceeds scanner limits and was not fully scanned.` |
| Explorer scan popup | Passed | The registered command line produced the expected popup for clean, EICAR, oversized, Unicode-named and missing files. It was launched directly, not by clicking the context menu. |
| Session cleanup | Passed | Refused a current-boot session; `-WhatIf` previewed without deleting; removed a synthetic previous-boot session. |
| Isolation input checks | Passed | A missing file, a non-PDF extension, and a `.pdf` without a PDF header each failed with `Isolation failed` (exit 1). |
| Explorer uninstall/reinstall | Passed | All three per-user registry verbs were removed and restored; saved scanner and viewer paths were preserved. |
| Sandbox guest | Not verified | Rendering in the guest, read-only mapping, no network, no clipboard, and disposal between sessions remain to be checked interactively. |
| Context menu click | Not verified | Selecting the entries by right-clicking in File Explorer has not been checked by hand. |

## Demo and remaining interactive checks

1. Right-click `examples\harmless.pdf` and select **Show more options → Scan with Click Quokka**. Expect `No threats detected`; scanning does not open it.
2. Right-click an accessible EICAR `.txt` file and scan it. Expect `Threat detected` with an EICAR signature. A Defender notification alone does not verify Click Quokka. If Defender removes it before the scan, record the test as blocked.
3. Right-click the sample PDF and select **Open in Click Quokka Isolation**. In the guest, confirm SumatraPDF displays it while offline. The host launch message alone does not establish that the viewer worked.
4. In the guest, open PowerShell and try `Set-Content C:\ClickQuokka\write-test.txt test`: it must fail. Check `Get-NetAdapter` and try reaching a known website; no network access should be available. Try copying unique text from the host to the guest and back; neither direction should transfer it. These are runtime checks, not conclusions from the `.wsb` configuration.
5. In the guest create `C:\Users\WDAGUtilityAccount\Desktop\quokka-marker.txt`, close the Sandbox session, and open the sample again in a new session. The marker must be absent. Then restart Windows before using the cleanup command above.
6. Check that a missing file and a `.txt` passed to isolated viewing fail clearly. Uninstall the actions, confirm they disappear for both PDF and TXT, reinstall, and confirm the saved dependency paths still work.

Record the Windows build, Sandbox version, viewer version, dates, and outcomes when running these checks. Keep any failed or blocked checks visible rather than presenting them as passed.
