param location string
param acrName string

@description('Object ID of the GitHub Actions service principal. When non-empty, grants AcrPush.')
param githubActionsPrincipalObjectId string = ''

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false // image pulls use managed identity, not admin credentials
  }
}

// Built-in role: AcrPush (8311e382-0749-4cb8-b61a-304f252e45ec)
resource acrPushAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(githubActionsPrincipalObjectId)) {
  name: guid(acr.id, githubActionsPrincipalObjectId, '8311e382-0749-4cb8-b61a-304f252e45ec')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
    principalId: githubActionsPrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

output name string = acr.name
output loginServer string = acr.properties.loginServer
output resourceId string = acr.id
