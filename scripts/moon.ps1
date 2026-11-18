param([Parameter(ValueFromRemainingArguments=$true)][string[]]$MoonArguments)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tool = $null
if ($env:MOON_BIN) { $tool = $env:MOON_BIN }
elseif ($env:MOON_HOME) { $tool = Join-Path $env:MOON_HOME 'bin\moon.exe' }
else {
    $command = Get-Command moon -ErrorAction SilentlyContinue
    if ($command) { $tool = $command.Source }
    else {
        $workspaceRoot = Split-Path -Parent $projectRoot
        $localTool = Join-Path $workspaceRoot '_tools\moon-audit-20261118\bin\moon.exe'
        if (Test-Path -LiteralPath $localTool) {
            $tool = $localTool
            $env:MOON_HOME = Split-Path -Parent (Split-Path -Parent $tool)
        }
    }
}
if (!$tool -or !(Test-Path -LiteralPath $tool)) { throw 'MoonBit is not available. Set MOON_HOME to your installation directory.' }
$toolDirectory = Split-Path -Parent $tool
$env:Path = "$toolDirectory;$env:Path"
Push-Location -LiteralPath $projectRoot
try { & $tool @MoonArguments; $result = $LASTEXITCODE }
finally { Pop-Location }
exit $result
