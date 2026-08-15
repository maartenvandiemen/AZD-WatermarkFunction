targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
  SecurityControl: 'Ignore'
}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module storageAccount './modules/storageAccount.bicep' = {
  name: 'storageAccount'
  scope: rg
  params: {
    tags: tags
    location: location
  }
}

module azureFunction './modules/azureFunction.bicep' = {
  name: 'azureFunction'
  scope: rg
  params: {
    tags: tags
    location: location
    storageAccountName: storageAccount.outputs.storageAccountName
    primaryBlobEndpoint: storageAccount.outputs.primaryBlobEndpoint
    deploymentContainerName: storageAccount.outputs.deploymentContainerName
  }
}

// Consumed by the postdeploy hook, which creates the Event Grid subscription that routes
// "input/" blob uploads to the function once its blob extension key exists.
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_FUNCTION_APP_NAME string = azureFunction.outputs.functionAppName
output AZURE_STORAGE_EVENT_GRID_TOPIC_NAME string = storageAccount.outputs.eventGridSystemTopicName
