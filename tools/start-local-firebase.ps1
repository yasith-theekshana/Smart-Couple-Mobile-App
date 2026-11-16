$ErrorActionPreference = 'Stop'
if (-not $env:JAVA_HOME) {
    $bundledJava = 'C:\Program Files\Android\Android Studio1\jbr'
    if (Test-Path -LiteralPath (Join-Path $bundledJava 'bin\java.exe')) {
        $env:JAVA_HOME = $bundledJava
        $env:Path = "$bundledJava\bin;$env:Path"
    }
}
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $savedData = Join-Path $projectRoot '.firebase\local-data'
    $firebaseArgs = @('emulators:start', '--only', 'auth,firestore,functions', '--project', 'demo-smart-couple', '--export-on-exit', $savedData)
    if (Test-Path -LiteralPath (Join-Path $savedData 'firebase-export-metadata.json')) {
        $firebaseArgs += @('--import', $savedData)
    }
    Write-Host 'Local test accounts are restored on start and saved on Ctrl+C. Keep this terminal open.'
    & firebase.cmd @firebaseArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
