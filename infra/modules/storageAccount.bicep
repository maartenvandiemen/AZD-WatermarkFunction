@description('The tags to associate with the resource')
param tags object

@description('The location for the resource')
param location string = resourceGroup().location

var uniqueName = uniqueString(resourceGroup().id, subscription().id)
var storageAccountName = 'storage${uniqueName}'
var deploymentContainerName = 'deploymentpackage'

module storageAccount 'br/public:avm/res/storage/storage-account:0.33.0' = {
  name: 'storageAccountDeployment'
  params: {
    name: storageAccountName
    location: location
    tags: tags
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    accessTier: 'Hot'
    enableHierarchicalNamespace: false
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    blobServices: {
      containers: [
        { name: 'input', publicAccess: 'None' }
        { name: 'output', publicAccess: 'None' }
        { name: deploymentContainerName, publicAccess: 'None' }
      ]
    }
    roleAssignments: [
      {
        principalId: deployer().objectId
        principalType: 'User'
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
      }
    ]
  }
}

output storageAccountName string = storageAccount.outputs.name
output primaryBlobEndpoint string = storageAccount.outputs.primaryBlobEndpoint
output deploymentContainerName string = deploymentContainerName
