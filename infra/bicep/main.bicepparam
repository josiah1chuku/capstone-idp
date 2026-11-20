using 'main.bicep'

// Values that differ per person or per run are read from environment variables,
// so nothing personal is committed. scripts/deploy.sh sets them.

param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus')
param prefix = 'idp'

// Pinned for reproducible experiments. Set KUBERNETES_VERSION, or change the default here
// after checking: az aks get-versions -l <region> -o table
param kubernetesVersion = readEnvironmentVariable('KUBERNETES_VERSION', '')

param systemNodeVmSize = 'Standard_D2s_v5'
param userNodeVmSize = 'Standard_D2s_v5'
param userNodeMaxCount = 2

param adminPrincipalId = readEnvironmentVariable('ADMIN_PRINCIPAL_ID', '')
param adminPrincipalType = 'User'

// Optional cost alerts. Leave BUDGET_ALERT_EMAIL unset to skip the budget.
param budgetAmount = 100
param budgetAlertEmail = readEnvironmentVariable('BUDGET_ALERT_EMAIL', '')
param budgetStartDate = readEnvironmentVariable('BUDGET_START_DATE', '')
