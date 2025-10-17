# Azure Policy: Allowed Arc Server Extensions

This folder contains a small, focused set of files to deploy a custom Azure Policy definition that audits Azure Arc-enabled server extensions which are not in an approved list, plus a helper to create a policy assignment.

Files
- `arc-server-extension-policy.json` — The custom policy definition JSON. This is a full policy definition (it includes `properties.parameters` and `properties.policyRule`). Use this file with the CLI scripts below.
- `Deploy-Policy-AzCLI.ps1` — Minimal PowerShell script that creates or updates the policy definition using `az policy definition create|update` and temporary `--rules` / `--params` files. Assumes `az login` is already done.
- `Deploy-PolicyAssignment-AzCLI.ps1` — Minimal PowerShell script to create or update a policy assignment for the policy definition. Supports assigning at subscription or resource-group scope and accepts a parameters JSON file.
- `Install-AzModules.ps1` — Optional PowerShell helpers to install Azure PowerShell modules if you prefer Az cmdlets instead of the CLI. Not required for the CLI-based scripts.

Quick prerequisites
- Azure CLI installed: https://aka.ms/azure-cli
- You must be logged in: `az login`
- You need owner or policy contributor rights on the target scope to create definitions and assignments.

How to deploy the policy definition (CLI)
1. From this folder, run (replace `<sub>`):

```powershell
.\Deploy-Policy-AzCLI.ps1 -SubscriptionId <sub> -PolicyFile .\arc-server-extension-policy.json -PolicyName audit-arc-server-extensions
```

2. If successful, the script will output the result from `az policy definition create|update`.

How to assign the policy
1. Basic subscription assignment:

```powershell
.\Deploy-PolicyAssignment-AzCLI.ps1 -SubscriptionId <sub> -PolicyName audit-arc-server-extensions -AssignmentName audit-arc-server-extensions-assignment
```

2. Assign to a resource group instead of subscription root (example):

```powershell
.\Deploy-PolicyAssignment-AzCLI.ps1 -SubscriptionId <sub> -PolicyName audit-arc-server-extensions -AssignmentName my-assignment -Scope "/subscriptions/<sub>/resourceGroups/my-rg"
```

3. Provide parameter values via a JSON file (example content below). Pass the file using `-ParamsFile .\assignment-params.json`:

`assignment-params.json` example:
```json
{
  "approvedExtensions": { "value": ["MicrosoftMonitoringAgent","DependencyAgentLinux"] }
}
```

Trigger a policy re-evaluation (optional)
- Trigger a scan for the subscription:
```powershell
az policy state trigger-scan --subscription <sub>
```
- Trigger a scan for a resource group:
```powershell
az policy state trigger-scan --resource-group <rg-name> --subscription <sub>
```

Check compliance / results
- Summarize compliance for subscription:
```powershell
az policy state summarize --subscription <sub>
```
- List recent evaluation records (top 50):
```powershell
az policy state list --subscription <sub> --top 50
```

Troubleshooting
- If `az policy definition create` complains about parameters or rules, ensure you're using the full policy JSON file (`arc-server-extension-policy.json`) and not only the `policyRule` object. The `Deploy-Policy-AzCLI.ps1` script extracts rules and parameters into temp files and passes them to the CLI.
- If `az policy state` commands are not available, add/update the policy extension: `az extension add --name policy` or update your Azure CLI.
- Permission errors: confirm you have Policy Contributor or Owner at the scope.


