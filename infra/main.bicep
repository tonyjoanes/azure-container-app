targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the Azure Container Registry. Must be globally unique, 5-50 alphanumeric characters.')
param acrName string = 'acrdemo${uniqueString(resourceGroup().id)}'

@description('Name of the Container Apps Environment.')
param environmentName string = 'cae-demo'

@description('Name of the Container App.')
param appName string = 'api-demo'

@description('Object ID of the GitHub Actions service principal. When provided, grants AcrPush on the registry so the workflow can push images.')
param githubActionsPrincipalObjectId string = ''

module registry 'modules/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    acrName: acrName
    githubActionsPrincipalObjectId: githubActionsPrincipalObjectId
  }
}

module app 'modules/app.bicep' = {
  name: 'app'
  params: {
    location: location
    environmentName: environmentName
    appName: appName
    acrName: acrName
    acrLoginServer: registry.outputs.loginServer
  }
}

output acrName string = registry.outputs.name
output acrLoginServer string = registry.outputs.loginServer
output appUrl string = app.outputs.appUrl
