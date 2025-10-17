<#
Deploy-Policy-AzCLI.ps1
Minimal script to deploy a policy definition using Azure CLI.
Assumptions: az CLI is installed and az login has already been performed.

Usage:
  .\Deploy-Policy-AzCLI.ps1 -SubscriptionId <sub-id> -PolicyFile .\arc-server-extension-policy.json -PolicyName audit-arc-server-extensions

This script extracts the policyRule and parameters from the given JSON (works when the file is a full policy definition or a rules-only object), writes temporary files for --rules and --params, and then runs `az policy definition create` or `az policy definition update`.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$false)]
    [string]$PolicyFile = ".\arc-server-extension-policy.json",

    [Parameter(Mandatory=$false)]
    [string]$PolicyName = "audit-arc-server-extensions",

    [Parameter(Mandatory=$false)]
    [string]$DisplayName = "Audit Arc-enabled Server Extensions Not in Approved List",

    [Parameter(Mandatory=$false)]
    [ValidateSet('Indexed','All')]
    [string]$Mode = 'Indexed'
)

$ErrorActionPreference = 'Stop'

Write-Host "Deploying policy (az CLI) - minimal" -ForegroundColor Green

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI 'az' not found. Install Azure CLI and run 'az login' before using this script."
    exit 1
}

# Resolve policy file
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$policyPath = Resolve-Path -Path (Join-Path $scriptDir $PolicyFile) -ErrorAction SilentlyContinue
if (-not $policyPath) { Write-Error "Policy file not found: $PolicyFile"; exit 1 }
$policyPath = $policyPath.Path

# Read JSON
try { $raw = Get-Content -Path $policyPath -Raw; $obj = $raw | ConvertFrom-Json } catch { Write-Error "Failed to read/parse policy JSON: $($_.Exception.Message)"; exit 1 }

# Extract rule and params
if ($null -ne $obj.properties -and $null -ne $obj.properties.policyRule) {
    $rules = $obj.properties.policyRule
    $params = $obj.properties.parameters
    if (-not $DisplayName -and $obj.properties.displayName) { $DisplayName = $obj.properties.displayName }
    $Description = $obj.properties.description
}
elseif ($null -ne $obj.policyRule) {
    $rules = $obj.policyRule
    $params = $obj.parameters
    if (-not $DisplayName -and $obj.displayName) { $DisplayName = $obj.displayName }
    $Description = $obj.description
}
else {
    # treat the file as rules-only
    $rules = $obj
    $params = $null
    $Description = $null
}

# Write temp files for rules and params
$rulesFile = [System.IO.Path]::GetTempFileName()
$rulesFile = [System.IO.Path]::ChangeExtension($rulesFile, '.json')
$rules | ConvertTo-Json -Depth 20 | Set-Content -Path $rulesFile -Encoding UTF8

$paramsFile = $null
if ($null -ne $params) {
    $paramsFile = [System.IO.Path]::GetTempFileName()
    $paramsFile = [System.IO.Path]::ChangeExtension($paramsFile, '.json')
    $params | ConvertTo-Json -Depth 20 | Set-Content -Path $paramsFile -Encoding UTF8
}

# Set subscription context
& az account set --subscription $SubscriptionId | Out-Null

# Check if definition exists
$exists = $false
try {
    $showOut = & az policy definition show --name $PolicyName --subscription $SubscriptionId
    if ($LASTEXITCODE -eq 0 -and $showOut) { $exists = $true }
} catch { $exists = $false }

# Build az args
if ($exists) { $action = 'update' } else { $action = 'create' }

$args = @('policy','definition',$action,'--name',$PolicyName)

if ($DisplayName) { $args += @('--display-name',$DisplayName) }
if ($Description) { $args += @('--description',$Description) }

# Rules and params are passed via file reference using the @file syntax. Ensure the CLI sees the @ prefix.
$rulesArg = "@{0}" -f $rulesFile
$args += @('--rules',$rulesArg)

if ($paramsFile) {
    $paramsArg = "@{0}" -f $paramsFile
    $args += @('--params',$paramsArg)
}

$args += @('--mode',$Mode,'--subscription',$SubscriptionId)

Write-Host "Running: az $($args -join ' ')" -ForegroundColor Yellow

# Execute
$out = & az @args 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "az command failed (exit $LASTEXITCODE). Output:"; Write-Host $out
    # cleanup
    if (Test-Path $rulesFile) { Remove-Item $rulesFile -ErrorAction SilentlyContinue }
    if ($paramsFile -and (Test-Path $paramsFile)) { Remove-Item $paramsFile -ErrorAction SilentlyContinue }
    exit 1
}

Write-Host $out

# Cleanup
if (Test-Path $rulesFile) { Remove-Item $rulesFile -ErrorAction SilentlyContinue }
if ($paramsFile -and (Test-Path $paramsFile)) { Remove-Item $paramsFile -ErrorAction SilentlyContinue }

Write-Host "Done." -ForegroundColor Green
