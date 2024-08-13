[CmdletBinding()]
param(
    [Parameter()]
    [string]$AppName = 'decap-auth-func-cms',

    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter()]
    [string]$Location = 'West Europe',

    [Parameter(Mandatory)]
    [string]$GitHubClientId,

    [Parameter(Mandatory)]
    [string]$GitHubClientSecret,

    [Parameter()]
    [hashtable]$Parameters
)

try {
    Get-AzContext -ErrorAction Stop
}
catch {
    throw 'Please run Connect-AzAccount to login to your Azure account!'
}

# Join hashtables for template parameters
$Params = @{
    githubClientId = $GitHubClientId
    gitHubClientSecret = $GitHubClientSecret
    appName = $AppName
}
foreach ($key in $Parameters.Keys) {
    $Params[$key] = $Parameters[$key]
}

# Hashtable for splatting
$DeployParams = @{
    ResourceGroupName = $ResourceGroupName
    Location = $Location
    TemplateParameterObject = $Params
    TemplateFile = 'auth-func.bicep'
    DeploymentName = 'auth-func'
}
# Deploy the resources
$Deployment = New-AzResourceGroupDeployment -ErrorAction Stop @DeployParams -Name "$AppName-$(New-Guid)"
$Deployment

$StorageName = $Deployment.Outputs.storageAccountName.Value

Start-Sleep -Seconds 10

# Deploy the function app code
# Since the function app is linux and a simple zip deployment is not supported, we need to use Azure Storage
# We upload the zip file to the storage account, which the function app will find based on already set app setting
$ArchivePath = "$AppName.zip"
# Needs to not have a root folder when zipped
Compress-Archive -Path './auth-func/*' -DestinationPath $ArchivePath -Force -ErrorAction Stop
$BlobParams = @{
    Context = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName).Context
    Container = $AppName
    Blob = $ArchivePath
    File = $ArchivePath
}
Set-AzStorageBlobContent @BlobParams -Force -ErrorAction Stop
Remove-Item -Path $ArchivePath -Force