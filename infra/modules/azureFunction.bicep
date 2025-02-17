@description('The tags to associate with the resource')
param tags object

param storageAccountName string

var uniqueName = uniqueString(resourceGroup().id, subscription().id)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource worskapce 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'workspace-${uniqueName}'
  location: resourceGroup().location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appInsights-${uniqueName}'
  location: resourceGroup().location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: worskapce.id
  }
}

resource servicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'serviceplan-${uniqueName}'
  location: resourceGroup().location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: false
  }
  kind: 'functionapp'
}

resource function 'Microsoft.Web/sites@2024-04-01' = {
  name: 'function-${uniqueName}'
  location: resourceGroup().location
  tags: union(tags, { 'azd-service-name': 'watermarkfunction' })
  kind: 'functionapp'
  properties: {
    serverFarmId: servicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'watermarkfunctionstorageAccount_STORAGE'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${storageAccountName}functions'
        }
      ]
    }
    clientAffinityEnabled: false
    httpsOnly: true
    reserved: false
  }
}
