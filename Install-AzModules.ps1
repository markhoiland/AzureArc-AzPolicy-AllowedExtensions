# Install Required Azure PowerShell Modules

Write-Host "Installing Azure PowerShell Modules..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Install required modules
$modules = @('Az.Accounts', 'Az.Resources', 'Az.PolicyInsights', 'Az.ConnectedMachine')

foreach ($module in $modules) {
    Write-Host "Installing $module..." -ForegroundColor Yellow
    Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    Write-Host "Installed $module" -ForegroundColor Green
}

Write-Host "All modules installed successfully!" -ForegroundColor Green
Write-Host "Next: Run Connect-AzAccount to sign in to Azure" -ForegroundColor Yellow