param([string]$Avd = 'Medium_Phone_API_37.0')
$ErrorActionPreference = 'Stop'
$sdkPath = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$emulatorPath = Join-Path $sdkPath 'emulator\emulator.exe'
if (-not (Test-Path -LiteralPath $emulatorPath)) { throw 'Android emulator executable was not found.' }
# Cold boot and software graphics avoid the corrupted GPU framebuffer observed
# on this machine. Existing AVD storage and installed apps are preserved.
Start-Process -FilePath $emulatorPath -ArgumentList '-avd', $Avd, '-no-snapshot-load', '-gpu', 'software' -WindowStyle Hidden
