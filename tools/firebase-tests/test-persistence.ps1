param([string]$Device = 'emulator-5554')
$ErrorActionPreference = 'Stop'
flutter test integration_test/auth_persistence_test.dart -d $Device --no-uninstall --dart-define=AUTH_PERSISTENCE_PHASE=seed
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter test integration_test/auth_persistence_test.dart -d $Device --dart-define=AUTH_PERSISTENCE_PHASE=restore
exit $LASTEXITCODE
