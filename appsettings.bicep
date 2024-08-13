@description('The name of the web app.')
param webAppName string

@description('The new app settings for the web app.')
param appSettings object

@description('The current app settings for the web app.')
param currentAppSettings object

resource webApp 'Microsoft.Web/sites@2022-03-01' existing = {
  name: webAppName
}

resource siteconfig 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: webApp
  name: 'appsettings'
  properties: union(currentAppSettings, appSettings)
}
