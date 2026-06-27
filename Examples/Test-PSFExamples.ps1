#Requires -Version 5.1
$ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-Module MSIXForcelets

# PSF examples on PuTTY, added one step at a time. Run section by section (the `break`
# statements stop a full run); inspect config.json.xml between steps.
#   1) PsfLauncher shim with a WORKING DIRECTORY
#   2) default PARAMETERS (arguments)
#   3) PsfTraceFixup with a trace/"debug" LEVEL  (-TraceLevel)
#   4) PsfMonitor (trace monitor), auto-started by PsfLauncher
# Trace/monitor docs:
#   https://github.com/TimMangan/MSIX-PackageSupportFramework/wiki#psftracefixup
#   https://github.com/TimMangan/MSIX-PackageSupportFramework/wiki/Debugging-with-PsfMonitor

# --- Configuration -----------------------------------------------------------

$CertPath           = "$ScriptRoot\NewSelfSigningCert.pfx"
$CertPassword       = 'mypass' | ConvertTo-SecureString -Force -AsPlainText
$MSIXSource         = "$env:USERPROFILE\Desktop\Putty_0.84.0.0_x64__0cfjrh7p5ggd2.msix"
$MSIXOutputFilename = "$env:USERPROFILE\Desktop\Putty_PSF_signed.msix"

# PuTTY's install location inside the package (backslashes for VFS paths).
$WorkingDirectory   = 'VFS\ProgramFilesX64\PuTTY'

# Default command line passed to putty.exe (parameters example). Empty = no defaults.
$Arguments          = ''

# -----------------------------------------------------------------------------

break

# --- Open package, align publisher, strip everything but PuTTY ----------------

$Subject = (Get-PfxData -FilePath $CertPath -Password $CertPassword).EndEntityCertificates.Subject
$Package = Open-MSIXPackage -MsixFile $MSIXSource -Force

Set-MSIXPublisher -MSIXFolder $Package -PublisherSubject $Subject
Backup-MSIXManifest -MSIXFolder $Package

# Drop the WindowsAppRuntime dependency and every desktop7 shortcut.
Get-MSIXDependencies -MSIXFolder $Package |
    Where-Object Name -like '*WindowsAppRuntime*' |
    Remove-MSIXDependencies -Verbose
Remove-MSIXDesktop7Shortcut -MSIXFolder $Package -Verbose

# Keep only putty.exe, remove all other applications.
$putty = Get-MSIXApplications -MSIXFolder $Package |
    Where-Object { $_.Executable -like '*putty.exe' } | Select-Object -First 1
foreach ($app in (Get-MSIXApplications -MSIXFolder $Package)) {
    if ($app.Id -ne $putty.Id) {
        Remove-MSIXApplications -MSIXFolder $Package -MISXAppID $app.Id -Verbose
    }
}

break

# --- PSF framework + trace + monitor binaries --------------------------------

# -TraceFixup copies TraceFixup*.dll; -IncludePSFMonitor copies PsfMonitor*.exe.
Add-MSIXPsfFrameworkFiles -MSIXFolder $Package -PSFArchitektur x64 `
    -TraceFixup -IncludePSFMonitor -Verbose

# To remove the monitor files again:
# Remove-MSIXPSFMonitorFiles -MSIXFolder $Package -Verbose

break

# --- 1) + 2) PsfLauncher shim: working directory + default parameters ---------
# The shim renames the AppId and repoints Executable to PsfLauncher; afterwards PuTTY
# is the only (now shimmed) application in the package.

Add-MSXIXPSFShim -MSIXFolder $Package -PSFArchitektur Auto -MISXAppID $putty.Id `
    -WorkingDirectory $WorkingDirectory -Arguments $Arguments -Verbose

break

# --- 3) PsfTraceFixup: trace putty.exe ---------------------------------------
# -Executable is a regex; -TraceLevel IS the "debug level" (verbosity):
#   always | allFailures | unexpectedFailures | ignoreSuccess | ignore
# traceMethod=eventlog -> PsfMonitor reads it (use outputDebugString for DebugView).

Add-MSIXPSFTracing -MSIXFolder $Package -Executable 'putty\.exe' `
    -TraceMethod eventlog -TraceLevel always -Verbose

break

# --- 4) PsfMonitor (trace monitor) -------------------------------------------
# PsfLauncher starts the monitor (as admin) before PuTTY so it captures the trace from
# the start. Only PuTTY remains, so the single (now shimmed) app gets the monitor entry.

$puttyApp = Get-MSIXApplications -MSIXFolder $Package | Select-Object -First 1
Add-MSIXPSFMonitor -MSIXFolder $Package -MISXAppID $puttyApp.Id `
    -Executable 'PsfMonitorx64.exe' -Asadmin -Verbose

# The elevated monitor needs these capabilities.
Add-MSIXCapabilities -MSIXFolder $Package -Capabilities 'runFullTrust', 'allowElevation' -Verbose

break

# --- Pack and sign -----------------------------------------------------------

$Package | Close-MSIXPackage -MSIXFile $MSIXOutputFilename -PrettyPrint -KeepMSIXFolder -Verbose
Set-MSIXSignature -MSIXFile $MSIXOutputFilename -PfxCert $CertPath -CertPassword $CertPassword -NoTimestamp

break

# --- Reinstall ---------------------------------------------------------------

Get-AppPackage *putty* | Remove-AppPackage
Add-AppPackage -Path $MSIXOutputFilename

# NOTE on the trace monitor (the part that did not work last time):
# PsfLauncher launches the monitor with asadmin=true, i.e. ELEVATED - an elevated process
# starts OUTSIDE the package's virtual environment, so it may not see PsfMonitorx64.exe placed
# into VFS\SystemX64 (this is the documented PSF limitation, see Add-MSIXPSFMonitor NOTES).
# Reliable fallback to read the eventlog trace if autostart shows nothing:
#   - run PsfMonitorx64.exe manually as admin, or
#   - use Sysinternals DebugView (Capture > Capture Global Win32 + Capture Events) while PuTTY runs
#     (set -TraceMethod outputDebugString above for the DebugView route).
