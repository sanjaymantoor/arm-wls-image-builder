# About WebLogic on Microsoft Azure

As part of a broad-ranging partnership between Oracle and Microsoft, this project offers support for running Oracle WebLogic Server in the Azure Virtual Machines and Azure Kubernetes Service (AKS). The partnership includes joint support for a range of Oracle software running on Azure, including Oracle WebLogic, Oracle Linux, and Oracle DB, as well as interoperability between Oracle Cloud Infrastructure (OCI) and Azure. 

## About repository
This repository contains Azure image builder scripts that can be used to install and setup WebLogic on supported Oracle Linux.

## Installation

The [Azure Marketplace WebLogic Server Offering](https://azuremarketplace.microsoft.com/en-us/marketplace/apps?search=WebLogic) a simplified UI and installation experience over the full power of the Azure Resource Manager (ARM) template.

## Documentation

Please refer to the README for [documentation on WebLogic Server running on an Azure Kubernetes Service](https://oracle.github.io/weblogic-kubernetes-operator/userguide/aks/)

Please refer to the README for [documentation on WebLogic Server running on an Azure Virtual Machine](https://docs.oracle.com/en/middleware/standalone/weblogic-server/wlazu/get-started-oracle-weblogic-server-microsoft-azure-iaas.html#GUID-E0B24A45-F496-4509-858E-103F5EBF67A7)

## Azure Image Builder Refernce

Refer [Azure Image Builder overview](https://docs.microsoft.com/en-us/azure/virtual-machines/image-builder-overview) for more details.
Before using the WLS image builder scripts, register the features as mentioned.
### Register the features
* az provider register -n Microsoft.VirtualMachineImages
* az provider register -n Microsoft.Compute
* az provider register -n Microsoft.KeyVault
* az provider register -n Microsoft.Storage
* az provider register -n Microsoft.Network

### Create a user-assigned identity and set permissions on the resource group
 * create user assigned identity for image builder to access the storage account where the script is located
  
     identityName=wlsimageidentity
  
     az identity create -g $resourceGroup-n $identityName

* get identity id

imgBuilderCliId=$(az identity show -g $resourceGroup -n $identityName --query clientId -o tsv)

* get the user identity URI, needed for the template

imgBuilderId=/subscriptions/$subscriptionID/resourcegroups/$resourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName

* Download an Azure role definition template, and update the template with the parameters specified earlier.

curl https://raw.githubusercontent.com/Azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json -o aibRoleImageCreation.json

imageRoleDefName="Azure Image Builder Image Def"$(date +'%s')

* update the definition

sed -i -e "s/\<subscriptionID\>/$subscriptionID/g" aibRoleImageCreation.json
  
sed -i -e "s/\<rgName\>/$resourceGroup/g" aibRoleImageCreation.json
  
sed -i -e "s/Azure Image Builder Service Image Creation Role/$imageRoleDefName/g" aibRoleImageCreation.json

* create role definitions

 az role definition create --role-definition ./aibRoleImageCreation.json

* grant role definition to the user assigned identity

  az role assignment create \
    --assignee $imgBuilderCliId \
    --role "$imageRoleDefName" \
    --scope /subscriptions/$subscriptionID/resourceGroups/$resourceGroup

### Details on parameters
| Parameter | Details |
|---|---|
|userAssignedIdentity| Provide </br> imgBuilderId=/subscriptions/$subscriptionID/resourcegroups/$resourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName|
| _artifactsLocation | Repoistory URL </br> For example, https://raw.githubusercontent.com/sanjaymantoor/wls-image-builder/master|
|wlsShiphomeURL| WebLogic shiphome URL stored in your Azure subscription storage account container ( SAS URI ). Make sure URL is accessible. </br> For example, https://mystorageaccount.blob.core.windows.net/shiphomes/fmw_14.1.1.0.0_wls_Disk1_1of1.zip|
|jdkURL | JDK8 or JDK11 shiphome URL stored in your Azure subscription storage account container ( SAS URI ). Make sure URL is accessible. </br> For example,https://mystorageaccount.blob.core.windows.net/shiphomes/jdk-8u291-linux-x64.tar.gz|
|wlsVersion| Provide WebLogic version. For example, 14.1.1.0.0 or 12.2.1.4.0 or 12.2.1.3.0|
|jdkVersion| Provide JDK version. For example, jdk1.8.0_291|
|linuxOSVersion| Provide Oracle Linux version. For example, 7.6 in case it is Oracle Linux 7.6. </br> Supported versions 7.3, 7.4 and 7.6|
|wlsPatchURL|Provide WebLogic patch stored in your Azure subscription storage account container ( SAS URI ).  Make sure URL is accessible. </br> |
|opatchURL|Provide OPatch stored in your Azure subscription storage account container ( SAS URI ).  Make sure URL is accessible. </br> |


