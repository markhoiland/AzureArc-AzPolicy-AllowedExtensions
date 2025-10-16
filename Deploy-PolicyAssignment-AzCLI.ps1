<#
Deploy-PolicyAssignment-AzCLI.ps1
Minimal PowerShell helper to create or update an Azure Policy Assignment using Azure CLI (no REST).
Assumptions: az CLI is installed and user has already run 'az login'.

Usage examples:
  # Assign at subscription scope (default)
  .\Deploy-PolicyAssignment-AzCLI.ps1 -SubscriptionId <sub-id> -PolicyName audit-arc-server-extensions -AssignmentName audit-arc-server-extensions-assignment

  # Assign to resource group
  .\Deploy-PolicyAssignment-AzCLI.ps1 -SubscriptionId <sub-id> -PolicyName audit-arc-server-extensions -AssignmentName my-assignment -Scope "/subscriptions/<sub-id>/resourceGroups/my-rg"

  # With parameter values from a JSON file
  .\Deploy-PolicyAssignment-AzCLI.ps1 -SubscriptionId <sub-id> -PolicyName audit-arc-server-extensions -ParamsFile .\assignment-params.json

The ParamsFile should be a JSON object in the form expected by az --params, for example:
{
  "approvedExtensions": { "value": ["ext1","ext2"] }
}
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$false)]
    [string]$PolicyName = "audit-arc-server-extensions",

    [Parameter(Mandatory=$false)]
    [string]$AssignmentName = "",

    [Parameter(Mandatory=$false)]
    [string]$Scope = "",

    [Parameter(Mandatory=$false)]
    [string]$ParamsFile = ""
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI 'az' not found. Install it and run 'az login' before using this script."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($AssignmentName)) {
    $AssignmentName = "$PolicyName-assignment"
}

# Default scope to the subscription root if not provided
if ([string]::IsNullOrWhiteSpace($Scope)) {
    $Scope = "/subscriptions/$SubscriptionId"
}

# Resolve params file if provided
if ($ParamsFile) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $paramsPath = Resolve-Path -Path (Join-Path $scriptDir $ParamsFile) -ErrorAction SilentlyContinue
    if (-not $paramsPath) { Write-Error "Params file not found: $ParamsFile"; exit 1 }
    $paramsPath = $paramsPath.Path
    $paramsArg = "@{0}" -f $paramsPath
} else {
    $paramsArg = $null
}

# Ensure subscription context
& az account set --subscription $SubscriptionId | Out-Null

# Build the full policy definition id (assignment accepts id or builtin alias)
$policyId = "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/policyDefinitions/$PolicyName"

# Check if assignment exists at the requested scope
$exists = $false
try {
    $show = & az policy assignment show --name $AssignmentName --scope $Scope 2>$null
    if ($LASTEXITCODE -eq 0 -and $show) { $exists = $true }
} catch { $exists = $false }

if ($exists) {
    Write-Host "Updating existing assignment '$AssignmentName' at scope: $Scope" -ForegroundColor Yellow
    $args = @('policy','assignment','update','--name',$AssignmentName,'--scope',$Scope,'--policy',$policyId,'--subscription',$SubscriptionId)
} else {
    Write-Host "Creating assignment '$AssignmentName' at scope: $Scope" -ForegroundColor Yellow
    $args = @('policy','assignment','create','--name',$AssignmentName,'--scope',$Scope,'--policy',$policyId,'--subscription',$SubscriptionId)
}

if ($paramsArg) { $args += @('--params',$paramsArg) }

Write-Host "Running: az $($args -join ' ')" -ForegroundColor Cyan
$out = & az @args 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "az command failed (exit $LASTEXITCODE). Output:"; Write-Host $out
    exit 1
}

Write-Host $out
Write-Host "Policy assignment complete." -ForegroundColor Green
