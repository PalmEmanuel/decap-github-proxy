targetScope = 'resourceGroup'

@description('The base app name for the resources.')
@maxLength(21)
param appName string = 'decap-auth-func'

@description('Name of storage account (cannot contain any other characters than lowercase a-z)')
@maxLength(24)
param storageAccountName string = replace('${appName}stg', '-', '')

@description('The SKU of the storage account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountSku string = 'Standard_LRS'

// Y1 is consumption
@description('SKU of app service plan.')
param appServicePlanSKU string = 'Y1'

@description('Name of app service plan.')
param appServicePlanName string = '${appName}-asp'

@description('Name of app insights.')
param appInsightsName string = '${appName}-appin'

@description('Name of log analytics workspace.')
param logAnalyticsName string = '${appName}-log'

@description('Name of diagnostic settings.')
param diagnosticsName string = '${appName}-ds'

@description('The location for the deployed resources.')
param location string = resourceGroup().location

@description('The client ID for the GitHub app - not GitHub OAuth app.')
param githubClientId string

@description('The client secret for the GitHub app - not GitHub OAuth app.')
@secure()
param githubClientSecret string

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value}'

var envVars = [
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: 'powershell'
  }
  {
    name: 'WEBSITE_CONTENTSHARE' // Required for Consumption
    value: toLower(appName)
  }
  {
    name: 'AzureWebJobsStorage__accountName'
    value: storageAccountName
  }
  {
    name: 'AzureWebJobsSecretStorageType'
    value: 'keyvault'
  }
  {
    name: 'WEBSITE_RUN_FROM_PACKAGE'
    value: '${storageAccount.properties.primaryEndpoints.blob}${appName}/${appName}.zip'
  }
  {
    name: 'AzureWebJobsSecretStorageKeyVaultUri'
    value: keyVault.properties.vaultUri
  }
  {
    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING' // Required for Consumption
    value: storageConnectionString
  }
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: '~4'
  }
  {
    name: 'FUNCTION_APP_EDIT_MODE'
    value: 'readonly'
  }
  {
    name: 'CALLBACK_TOKEN_URI'
    value: 'https://${functionApp.properties.defaultHostName}/api/callback'
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsights.properties.InstrumentationKey
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsights.properties.ConnectionString
  }
  {
    name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
    value: '~2'
  }
]

var secrets = [
  {
    name: 'GitHubClientId'
    value: githubClientId
  }
  {
    name: 'GitHubClientSecret'
    value: githubClientSecret
  }
]

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${appName}-kv'
  location: location
  properties: {
    tenantId: subscription().tenantId
    // enableRbacAuthorization: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: functionApp.identity.principalId
        // grant full access to the secrets and keys to create too
        permissions: {
          keys: [
            'get'
            'list'
            'create'
            'delete'
            'update'
            'import'
            'backup'
            'restore'
            'recover'
            'purge'
          ]
          secrets: [
            'get'
            'list'
            'set'
            'delete'
            'recover'
            'backup'
            'restore'
            'purge'
          ]
          certificates: [
            'get'
            'list'
            'create'
            'delete'
            'update'
            'import'
            'backup'
            'restore'
            'recover'
            'purge'
          ]
        }
      }
    ]
  }

  resource keyVaultSecrets 'secrets' = [
    for secret in secrets: {
      name: secret.name
      properties: {
        value: secret.value
      }
    }
  ]
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {
    reserved: true
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: location
  name: logAnalyticsName
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: {
    'hidden-link:${resourceId('Microsoft.Web/sites', appName)}': 'Resource'
  }
  properties: {
    WorkspaceResourceId: logAnalyticsWorkspace.id
    Flow_Type: 'Bluefield'
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

resource diagnosticLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticsName
  scope: functionApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        enabled: true
        category: 'FunctionAppLogs'
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
    accessTier: 'Hot'
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }

  resource blobService 'blobServices' = {
    name: 'default'

    resource container 'containers' = {
      name: appName
    }
  }
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: appName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    reserved: true
    httpsOnly: true
    serverFarmId: appServicePlan.id
    siteConfig: {
      minTlsVersion: '1.2'
      linuxFxVersion: 'PowerShell|7.4'
      // Don't include app settings, set them below
    }
  }
  dependsOn: [
    appInsights
  ]
}

// Create-Update the webapp app settings.
module appSettings 'appsettings.bicep' = {
  name: '${appName}-appsettings'
  params: {
    webAppName: functionApp.name
    // Get the current appsettings
    currentAppSettings: list(resourceId('Microsoft.Web/sites/config', functionApp.name, 'appsettings'), '2022-03-01').properties
    appSettings: union(
      reduce(
        secrets,
        {},
        (cur, next) =>
          union(cur, {
            '${next.name}': '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/${next.name})'
          })
      ),
      reduce(
        envVars,
        {},
        (cur, next) =>
          union(cur, {
            '${next.name}': next.value
          })
      )
    )
  }
}

var kvOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
resource kvOfficerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: kvOfficerRoleId
}

resource roleAssignmentKVOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kvOfficerRoleId, appName)
  scope: keyVault
  properties: {
    roleDefinitionId: kvOfficerRoleDefinition.id
    principalId: functionApp.identity.principalId
  }
}

// Role assignments
var blobOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
resource roleDefinitionBlobContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: blobOwnerRoleId
}

resource roleAssignmentBlobOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appName, blobOwnerRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: roleDefinitionBlobContributor.id
    principalId: functionApp.identity.principalId
  }
}

var storageContributorRoleId = '17d1049b-9a84-46fb-8f53-869881c3d3ab'
resource roleDefinitionStorageContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: storageContributorRoleId
}

resource roleAssignmentStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appName, storageContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: roleDefinitionStorageContributor.id
    principalId: functionApp.identity.principalId
  }
}

output storageAccountName string = storageAccountName
