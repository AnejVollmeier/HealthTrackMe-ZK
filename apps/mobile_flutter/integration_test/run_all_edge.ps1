param(
    [string]$ChromeBinary = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    [string]$Config = '.env.e2e.json',
    [int]$WebPort = 52145,
    [int]$DriverPort = 4444,
    [switch]$Visible,
    [ValidateSet('fs_01_tp02', 'fs_01_tp01', 'fs_02_tp01', 'fs_02_tp02', 'fs_03_tp01', 'fs_03_tp02')]
    [string[]]$Cases = @('fs_01_tp02', 'fs_01_tp01', 'fs_02_tp01', 'fs_02_tp02', 'fs_03_tp01', 'fs_03_tp02')
)

$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    $settings = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
    if ($settings.API_BASE_URL -notin @('http://localhost:18080/api/v1', 'http://127.0.0.1:18080/api/v1') -or
        "$($settings.E2E_ISOLATED_DATABASE)" -ne 'true') {
        throw 'Use the isolated API on port 18080 and E2E_ISOLATED_DATABASE=true.'
    }
    if (-not (Test-Path -LiteralPath $ChromeBinary -PathType Leaf)) {
        throw "Chrome binary missing: $ChromeBinary"
    }
    $results = @()
    $logDirectory = Join-Path 'build' ('e2e/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    foreach ($case in $Cases) {
        $driver = 'test_driver/integration_test.dart'
        if ($case -eq 'fs_02_tp01') { $driver = 'test_driver/reload_integration_test.dart' }
        $visibility = '--headless'
        if ($Visible) { $visibility = '--no-headless' }
        $arguments = @('drive', '--no-pub', "--driver=$driver",
            "--target=integration_test/${case}_test.dart", '-d', 'web-server',
            "--web-port=$WebPort", '--browser-name=edge', "--driver-port=$DriverPort",
            $visibility, "--dart-define-from-file=$Config")
        Write-Host "Running $case"
        $log = Join-Path $logDirectory "$case.log"
        # Native stderr contains Flutter progress; preserve it without treating it
        # as a terminating PowerShell error. Exit code + final marker decide PASS.
        $ErrorActionPreference = 'Continue'
        & flutter @arguments > $log 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $passed = $code -eq 0 -and (Select-String -LiteralPath $log -SimpleMatch 'All tests passed.' -Quiet)
        $status = if ($passed) { 'PASS' } else { 'FAIL' }
        Write-Host "$status $case (log: $log)"
        $results += [pscustomobject]@{ Test = $case; Status = $status; ExitCode = $code; Log = $log }
    }
    $results | Format-Table -AutoSize
    $results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logDirectory 'results.json') -Encoding UTF8
    if ($results.Status -contains 'FAIL') { exit 1 }
} finally {
    Pop-Location
}


