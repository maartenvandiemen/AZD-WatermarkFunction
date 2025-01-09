@description('The tags to associate with the resource')
param tags object

var uniqueName = uniqueString(resourceGroup().id, subscription().id)

var storageaccntContainers = [
  'input'
  'output'
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'storage${uniqueName}'
  location: resourceGroup().location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties:{
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    isHnsEnabled: true
    supportsHttpsTrafficOnly: true
  }  
}

resource storageAccountBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource storageAccountContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = [for container in storageaccntContainers: {
  name: container
  parent: storageAccountBlobService
  properties: {
    publicAccess: 'None'
  }
}]

output storageAccountName string = storageAccount.name
