metadata name = 'Virtual Machine Image Templates'
metadata description = 'This module deploys a Virtual Machine Image Template that can be consumed by Azure Image Builder (AIB).'

@description('Required. The name prefix of the Image Template to be built by the Azure Image Builder service.')
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. The image build timeout in minutes. 0 means the default 240 minutes.')
@minValue(0)
@maxValue(960)
param buildTimeoutInMinutes int = 0

@description('Optional. Specifies the size for the VM.')
param vmSize string = 'Standard_D2s_v3'

@description('Optional. Specifies the size of OS disk.')
param osDiskSizeGB int = 128

@description('Required. Image source definition in object format.')
param imageSource resourceInput<'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01'>.properties.source

@description('Optional. Customization steps to be run when building the VM image.')
param customizationSteps resourceInput<'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01'>.properties.customize?

@description('Optional. Resource ID of the staging resource group in the same subscription and location as the image template that will be used to build the image.</p>If this field is empty, a resource group with a random name will be created.</p>If the resource group specified in this field doesn\'t exist, it will be created with the same name.</p>If the resource group specified exists, it must be empty and in the same region as the image template.</p>The resource group created will be deleted during template deletion if this field is empty or the resource group specified doesn\'t exist,</p>but if the resource group specified exists the resources created in the resource group will be deleted during template deletion and the resource group itself will remain.')
param stagingResourceGroupResourceId string?

import { lockType } from 'br/public:avm/utl/types/avm-common-types:0.5.1'
@description('Optional. The lock settings of the service.')
param lock lockType?

@description('Optional. Tags of the resource.')
param tags resourceInput<'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01'>.tags?

@description('Generated. Do not provide a value! This date is used to generate a unique image template name.')
param baseTime string = utcNow('yyyy-MM-dd-HH-mm-ss')

@description('Optional. Enable/Disable usage telemetry for module.')
param enableTelemetry bool = true

import { roleAssignmentType } from 'br/public:avm/utl/types/avm-common-types:0.5.1'
@description('Optional. Array of role assignments to create.')
param roleAssignments roleAssignmentType[]?

@description('Required. The distribution targets where the image output needs to go to.')
param distributions distributionType[]

@description('Optional. List of User-Assigned Identities associated to the Build VM for accessing Azure resources such as Key Vaults from your customizer scripts. Be aware, the user assigned identities specified in the \'managedIdentities\' parameter must have the \'Managed Identity Operator\' role assignment on all the user assigned identities specified in this parameter for Azure Image Builder to be able to associate them to the build VM.')
param vmUserAssignedIdentities string[] = []

import { managedIdentityOnlyUserAssignedType } from 'br/public:avm/utl/types/avm-common-types:0.5.1'
@description('Required. The managed identity definition for this resource.')
param managedIdentities managedIdentityOnlyUserAssignedType

@description('Optional. Configuration options and list of validations to be performed on the resulting image.')
param validationProcess validationProcessType?

@allowed([
  'Enabled'
  'Disabled'
])
@description('Optional. The optimize property can be enabled while creating a VM image and allows VM optimization to improve image creation time.')
param optimizeVmBoot string?

@allowed([
  'Enabled'
  'Disabled'
])
@description('Optional. Indicates whether or not to automatically run the image template build on template creation or update.')
param autoRunState string = 'Disabled'

@allowed([
  'cleanup'
  'abort'
])
@description('Optional. If there is a customizer error and this field is set to \'cleanup\', the build VM and associated network resources will be cleaned up. This is the default behavior. If there is a customizer error and this field is set to \'abort\', the build VM will be preserved.')
param errorHandlingOnCustomizerError string = 'cleanup'

@allowed([
  'cleanup'
  'abort'
])
@description('Optional. If there is a validation error and this field is set to \'cleanup\', the build VM and associated network resources will be cleaned up. If there is a validation error and this field is set to \'abort\', the build VM will be preserved. This is the default behavior.')
param errorHandlingOnValidationError string = 'cleanup'

@description('Optional. Tags that will be applied to the resource group and/or resources created by the service.')
param managedResourceTags resourceInput<'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01'>.properties.managedResourceTags?

@description('Optional. Optional configuration of the virtual network to use to deploy the build VM and validation VM in. Omit if no specific virtual network needs to be used.')
param vnetConfig vnetConfigType?

var identity = {
  type: 'UserAssigned'
  userAssignedIdentities: reduce(
    map((managedIdentities.?userAssignedResourceIds ?? []), (id) => { '${id}': {} }),
    {},
    (cur, next) => union(cur, next)
  ) // Converts the flat array to an object like { '${id1}': {}, '${id2}': {} }
}

var builtInRoleNames = {
  Contributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  Owner: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  Reader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  'Role Based Access Control Administrator': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'f58310d9-a9f6-439a-9e8d-f62e7b41a168'
  )
  'User Access Administrator': subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
  )
}

var formattedRoleAssignments = [
  for (roleAssignment, index) in (roleAssignments ?? []): union(roleAssignment, {
    roleDefinitionId: builtInRoleNames[?roleAssignment.roleDefinitionIdOrName] ?? (contains(
        roleAssignment.roleDefinitionIdOrName,
        '/providers/Microsoft.Authorization/roleDefinitions/'
      )
      ? roleAssignment.roleDefinitionIdOrName
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignment.roleDefinitionIdOrName))
  })
]

#disable-next-line no-deployments-resources
resource avmTelemetry 'Microsoft.Resources/deployments@2024-03-01' = if (enableTelemetry) {
  name: '46d3xbcp.res.virtualmachineimages-imagetemplate.${replace('-..--..-', '.', '-')}.${substring(uniqueString(deployment().name, location), 0, 4)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
      outputs: {
        telemetry: {
          type: 'String'
          value: 'For more information, see https://aka.ms/avm/TelemetryInfo'
        }
      }
    }
  }
}

resource imageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01' = {
  #disable-next-line use-stable-resource-identifiers // Disabling as ImageTemplates are not idempotent and hence always must have new name
  name: '${name}-${baseTime}'
  location: location
  tags: tags
  identity: identity
  properties: {
    buildTimeoutInMinutes: buildTimeoutInMinutes
    vmProfile: {
      vmSize: vmSize
      osDiskSizeGB: osDiskSizeGB
      userAssignedIdentities: vmUserAssignedIdentities
      vnetConfig: !empty(vnetConfig)
        ? {
            subnetId: vnetConfig.?subnetResourceId
            containerInstanceSubnetId: vnetConfig.?containerInstanceSubnetResourceId
            proxyVmSize: vnetConfig.?proxyVmSize
          }
        : null
    }
    source: imageSource
    ...(!empty(customizationSteps)
      ? {
          customize: customizationSteps
        }
      : {})
    stagingResourceGroup: stagingResourceGroupResourceId
    distribute: map(distributions, distribution => {
      type: distribution.type
      artifactTags: distribution.?artifactTags ?? {
        sourceType: imageSource.type
        sourcePublisher: imageSource.?publisher
        sourceOffer: imageSource.?offer
        sourceSku: imageSource.?sku
        sourceVersion: imageSource.?version
        sourceImageId: imageSource.?imageId
        sourceImageVersionID: imageSource.?imageVersionID
        creationTime: baseTime
      }
      ...(distribution.type == 'ManagedImage'
        ? {
            runOutputName: distribution.?runOutputName ?? '${distribution.imageName}-${baseTime}-ManagedImage'
            location: distribution.?location ?? location
            #disable-next-line use-resource-id-functions // Disabling rule as this is an input parameter that is used inside an array.
            imageId: distribution.?imageResourceId ?? '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Compute/images/${distribution.imageName}-${baseTime}'
          }
        : {})
      ...(distribution.type == 'SharedImage'
        ? {
            runOutputName: distribution.?runOutputName ?? '${last(split(distribution.?sharedImageGalleryImageDefinitionResourceId, '/'))}-SharedImage'
            galleryImageId: !empty(distribution.?sharedImageGalleryImageDefinitionTargetVersion)
              ? '${distribution.sharedImageGalleryImageDefinitionResourceId}/versions/${distribution.sharedImageGalleryImageDefinitionTargetVersion}'
              : distribution.sharedImageGalleryImageDefinitionResourceId
            excludeFromLatest: distribution.?excludeFromLatest ?? false
            replicationRegions: distribution.?replicationRegions ?? [location]
            storageAccountType: distribution.?storageAccountType ?? 'Standard_LRS'
          }
        : {})
      ...(distribution.type == 'VHD'
        ? {
            runOutputName: distribution.?runOutputName ?? '${distribution.imageName}-VHD'
          }
        : {})
    })
    #disable-next-line BCP225 //  The discriminator property "type" value cannot be determined at compilation time. - which is fine
    validate: validationProcess
    optimize: optimizeVmBoot != null
      ? {
          vmBoot: {
            state: optimizeVmBoot
          }
        }
      : null
    autoRun: {
      state: autoRunState
    }
    errorHandling: {
      onCustomizerError: errorHandlingOnCustomizerError
      onValidationError: errorHandlingOnValidationError
    }
    managedResourceTags: managedResourceTags
  }
}

resource imageTemplate_lock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(lock ?? {}) && lock.?kind != 'None') {
  name: lock.?name ?? 'lock-${name}'
  properties: {
    level: lock.?kind ?? ''
    notes: lock.?kind == 'CanNotDelete'
      ? 'Cannot delete resource or child resources.'
      : 'Cannot delete or modify the resource or child resources.'
  }
  scope: imageTemplate
}

resource imageTemplate_roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (roleAssignment, index) in (formattedRoleAssignments ?? []): {
    name: roleAssignment.?name ?? guid(imageTemplate.id, roleAssignment.principalId, roleAssignment.roleDefinitionId)
    properties: {
      roleDefinitionId: roleAssignment.roleDefinitionId
      principalId: roleAssignment.principalId
      description: roleAssignment.?description
      principalType: roleAssignment.?principalType
      condition: roleAssignment.?condition
      conditionVersion: !empty(roleAssignment.?condition) ? (roleAssignment.?conditionVersion ?? '2.0') : null // Must only be set if condtion is set
      delegatedManagedIdentityResourceId: roleAssignment.?delegatedManagedIdentityResourceId
    }
    scope: imageTemplate
  }
]

@description('The resource ID of the image template.')
output resourceId string = imageTemplate.id

@description('The resource group the image template was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The full name of the deployed image template.')
output name string = imageTemplate.name

@description('The prefix of the image template name provided as input.')
output namePrefix string = name

@description('The command to run in order to trigger the image build.')
output runThisCommand string = 'Invoke-AzResourceAction -ResourceName ${imageTemplate.name} -ResourceGroupName ${resourceGroup().name} -ResourceType Microsoft.VirtualMachineImages/imageTemplates -Action Run -Force'

@description('The location the resource was deployed into.')
output location string = imageTemplate.location

// =============== //
//   Definitions   //
// =============== //

@export()
@discriminator('type')
type distributionType = sharedImageDistributionType | managedImageDistributionType | unManagedDistributionType

@export()
@description('The type for a shared image distribution.')
type sharedImageDistributionType = {
  @description('Optional. The name to be used for the associated RunOutput. If not provided, a name will be calculated.')
  runOutputName: string?

  @description('Optional. Tags that will be applied to the artifact once it has been created/updated by the distributor. If not provided will set tags based on the provided image source.')
  artifactTags: object?

  @description('Required. The type of distribution.')
  type: 'SharedImage'

  @description('Required. Resource ID of Compute Gallery Image Definition to distribute image to, e.g.: /subscriptions/<subscriptionID>/resourceGroups/<SIG resourcegroup>/providers/Microsoft.Compute/galleries/<SIG name>/images/<image definition>.')
  sharedImageGalleryImageDefinitionResourceId: string

  @description('Optional. Version of the Compute Gallery Image. Supports the following Version Syntax: Major.Minor.Build (i.e., \'1.1.1\' or \'10.1.2\'). If not provided, a version will be calculated.')
  sharedImageGalleryImageDefinitionTargetVersion: string?

  @description('Optional. The exclude from latest flag of the image. Defaults to [false].')
  excludeFromLatest: bool?

  @description('Optional. The replication regions of the image. Defaults to the value of the \'location\' parameter.')
  replicationRegions: string[]?

  @description('Optional. The storage account type of the image. Defaults to [Standard_LRS].')
  storageAccountType: ('Standard_LRS' | 'Standard_ZRS')?
}

@export()
@description('The type for an unmanaged distribution.')
type unManagedDistributionType = {
  @description('Required. The type of distribution.')
  type: 'VHD'

  @description('Optional. The name to be used for the associated RunOutput. If not provided, a name will be calculated.')
  runOutputName: string?

  @description('Optional. Tags that will be applied to the artifact once it has been created/updated by the distributor. If not provided will set tags based on the provided image source.')
  artifactTags: object?

  @description('Required. Name of the managed or unmanaged image that will be created.')
  imageName: string
}

@export()
@description('The type for a managed image distribution.')
type managedImageDistributionType = {
  @description('Required. The type of distribution.')
  type: 'ManagedImage'

  @description('Optional. The name to be used for the associated RunOutput. If not provided, a name will be calculated.')
  runOutputName: string?

  @description('Optional. Tags that will be applied to the artifact once it has been created/updated by the distributor. If not provided will set tags based on the provided image source.')
  artifactTags: object?

  @description('Optional. Azure location for the image, should match if image already exists. Defaults to the value of the \'location\' parameter.')
  location: string?

  @description('Optional. The resource ID of the managed image. Defaults to a compute image with name \'imageName-baseTime\' in the current resource group.')
  imageResourceId: string?

  @description('Required. Name of the managed or unmanaged image that will be created.')
  imageName: string
}

@export()
@description('The type for a validation process.')
type validationProcessType = {
  @description('Optional. If validation fails and this field is set to false, output image(s) will not be distributed. This is the default behavior. If validation fails and this field is set to true, output image(s) will still be distributed. Please use this option with caution as it may result in bad images being distributed for use. In either case (true or false), the end to end image run will be reported as having failed in case of a validation failure. [Note: This field has no effect if validation succeeds.].')
  continueDistributeOnFailure: bool?

  @description('Optional. A list of validators that will be performed on the image. Azure Image Builder supports File, PowerShell and Shell validators.')
  inVMValidations: {
    @description('Required. The type of validation.')
    type: ('PowerShell' | 'Shell' | 'File')

    @description('Optional. Friendly Name to provide context on what this validation step does.')
    name: string?

    @description('Optional. URI of the PowerShell script to be run for validation. It can be a github link, Azure Storage URI, etc.')
    scriptUri: string?

    @description('Optional. Array of commands to be run, separated by commas.')
    inline: string[]?

    @description('Optional. Valid codes that can be returned from the script/inline command, this avoids reported failure of the script/inline command.')
    validExitCodes: int[]?

    @description('Optional. Value of sha256 checksum of the file, you generate this locally, and then Image Builder will checksum and validate.')
    sha256Checksum: string?

    @description('Optional. The source URI of the file.')
    sourceUri: string?

    @description('Optional. Destination of the file.')
    destination: string?

    @description('Optional. If specified, the PowerShell script will be run with elevated privileges using the Local System user. Can only be true when the runElevated field above is set to true.')
    runAsSystem: bool?

    @description('Optional. If specified, the PowerShell script will be run with elevated privileges.')
    runElevated: bool?
  }[]?

  @description('Optional. If this field is set to true, the image specified in the \'source\' section will directly be validated. No separate build will be run to generate and then validate a customized image. Not supported when performing customizations, validations or distributions on the image.')
  sourceValidationOnly: bool?
}

@export()
@description('The type for the virtual network configuration.')
type vnetConfigType = {
  @description('Optional. Resource id of a pre-existing subnet on which the build VM and validation VM will be deployed.')
  subnetResourceId: string?

  @description('Optional. Resource id of a pre-existing subnet on which Azure Container Instance will be deployed for Isolated Builds. This field may be specified only if subnetResourceId is also specified and must be on the same Virtual Network as the subnet specified in subnetResourceId.')
  containerInstanceSubnetResourceId: string?

  @description('Optional. Size of the proxy virtual machine used to pass traffic to the build VM and validation VM. This must not be specified if containerInstanceSubnetResourceId is specified because no proxy virtual machine is deployed in that case. Omit or specify empty string to use the default (Standard_A1_v2).')
  proxyVmSize: string?
}
