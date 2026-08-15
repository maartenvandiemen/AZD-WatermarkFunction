@description('The tags to associate with the resource')
param tags object

@description('The location for the resource')
param location string = resourceGroup().location

param storageAccountName string
param primaryBlobEndpoint string
param deploymentContainerName string

var uniqueName = uniqueString(resourceGroup().id, subscription().id)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.16.1' = {
  name: 'logAnalyticsWorkspace'
  params: {
    name: 'workspace-${uniqueName}'
    location: location
    tags: tags
  }
}

module appInsights 'br/public:avm/res/insights/component:0.8.0' = {
  name: 'appInsights'
  params: {
    name: 'appInsights-${uniqueName}'
    location: location
    tags: tags
    workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
  }
}

module servicePlan 'br/public:avm/res/web/serverfarm:0.7.0' = {
  name: 'servicePlan'
  params: {
    name: 'serviceplan-${uniqueName}'
    location: location
    tags: tags
    skuName: 'FC1'
    reserved: true
  }
}

module functionApp 'br/public:avm/res/web/site:0.24.0' = {
  name: 'functionApp'
  params: {
    name: 'function-${uniqueName}'
    location: location
    tags: union(tags, { 'azd-service-name': 'watermarkfunction' })
    kind: 'functionapp,linux'
    serverFarmResourceId: servicePlan.outputs.resourceId
    httpsOnly: true
    managedIdentities: {
      systemAssigned: true
    }
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${primaryBlobEndpoint}${deploymentContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 1
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '10.0'
      }
    }
    configs: [
      {
        name: 'appsettings'
        properties: {
          AzureWebJobsStorage__credential: 'managedidentity'
          AzureWebJobsStorage__blobServiceUri: 'https://${storageAccountName}.blob.${environment().suffixes.storage}'
          AzureWebJobsStorage__queueServiceUri: 'https://${storageAccountName}.queue.${environment().suffixes.storage}'
          APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.outputs.connectionString
        }
      }
    ]
  }
}

// Flex Consumption hosts the deployment package and the AzureWebJobsStorage blob trigger/lock
// state via managed identity instead of an account key, so the function's identity needs
// data-plane RBAC directly on the storage account.
resource storageBlobDataOwnerForFunction 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, uniqueName, 'Storage Blob Data Owner')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalId: functionApp.outputs.systemAssignedMIPrincipalId!
    principalType: 'ServicePrincipal'
  }
}

resource storageQueueDataContributorForFunction 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, uniqueName, 'Storage Queue Data Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
    principalId: functionApp.outputs.systemAssignedMIPrincipalId!
    principalType: 'ServicePrincipal'
  }
}

output functionAppName string = functionApp.outputs.name
