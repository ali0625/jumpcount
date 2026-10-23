[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('Check', 'Pair', 'DeveloperMode', 'Login', 'Sign', 'Install')]
    [string]$Action,
    [string]$AppPath = '.watchos/apps/RopeSkipStandalone.app'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$state = Join-Path $repo '.watchos'
$python = Join-Path $state 'python/python.exe'
$helper = Join-Path $state 'xtool-source/tools/watchos/watch_device.py'
$deviceInfo = Join-Path $state 'device.json'
$distro = 'Ubuntu-24.04'

function Invoke-Checked {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $File" }
}
function Convert-ToWslPath([string]$Path) {
    $value = & wsl.exe -d $distro -u ropeskip --exec wslpath -a -u $Path
    if ($LASTEXITCODE -ne 0) { throw 'WSL path conversion failed.' }
    return ($value -join "`n").Trim()
}

Push-Location $repo
try {
    if ($Action -eq 'Login') {
        # Interactive login: no password in arguments, files, transcripts, or GitHub.
        Invoke-Checked 'wsl.exe' @('-d', $distro, '-u', 'ropeskip', '--exec',
            '/opt/ropeskip/run-xtool', 'auth', 'login', '--mode', 'password')
        return
    }
    if ($Action -eq 'Sign') {
        if (!(Test-Path -LiteralPath $deviceInfo)) { throw 'Run Pair first to create private Watch device info.' }
        $app = (Resolve-Path -LiteralPath $AppPath).Path
        Invoke-Checked 'wsl.exe' @('-d', $distro, '-u', 'ropeskip', '--exec',
            '/opt/ropeskip/run-xtool', 'dev', 'sign-watch', (Convert-ToWslPath $app),
            '--device-info', (Convert-ToWslPath $deviceInfo))
        return
    }
    if (!(Test-Path -LiteralPath $python) -or !(Test-Path -LiteralPath $helper)) {
        throw 'Windows Watch runtime has not been prepared under .watchos.'
    }
    if ($Action -eq 'Check') {
        Invoke-Checked $python @('--version')
        Invoke-Checked $python @('-c', 'from importlib.metadata import version; print("pymobiledevice3 " + version("pymobiledevice3"))')
        Invoke-Checked 'wsl.exe' @('-d', $distro, '-u', 'ropeskip', '--exec',
            '/opt/ropeskip/run-xtool', 'dev', 'sign-watch', '--help')
        return
    }
    $helperArgs = @($helper, '--state-directory', $state)
    switch ($Action) {
        'Pair' {
            $helperArgs += '--pair'
            if (!(Test-Path -LiteralPath $deviceInfo)) { $helperArgs += @('--device-info', $deviceInfo) }
        }
        'DeveloperMode' { $helperArgs += '--reveal-developer-mode' }
        'Install' { $helperArgs += @('--install', (Resolve-Path -LiteralPath $AppPath).Path) }
    }
    Invoke-Checked $python $helperArgs
} finally { Pop-Location }
