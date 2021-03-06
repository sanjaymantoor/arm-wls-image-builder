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

## Register the features
* az provider register -n Microsoft.VirtualMachineImages
* az provider register -n Microsoft.Compute
* az provider register -n Microsoft.KeyVault
* az provider register -n Microsoft.Storage
* az provider register -n Microsoft.Network

## Create a user-assigned identity and set permissions on the resource group
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

## Details on parameters
| Parameter | Details |
|---|---|
|userAssignedIdentity| Provide </br> imgBuilderId=/subscriptions/$subscriptionID/resourcegroups/$resourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName|
| \_artifactsLocation | Repoistory URL </br> For example, https://raw.githubusercontent.com/sanjaymantoor/wls-image-builder/master|
|wlsShiphomeURL| WebLogic shiphome URL stored in your Azure subscription storage account container ( SAS URI ). Make sure URL is accessible. </br> For example, https://mystorageaccount.blob.core.windows.net/shiphomes/fmw_14.1.1.0.0_wls_Disk1_1of1.zip|
|jdkURL | JDK8 or JDK11 shiphome URL stored in your Azure subscription storage account container ( SAS URI ). Make sure URL is accessible. </br> For example,https://mystorageaccount.blob.core.windows.net/shiphomes/jdk-8u291-linux-x64.tar.gz|
|wlsVersion| Provide WebLogic version. For example, 14.1.1.0.0 or 12.2.1.4.0 or 12.2.1.3.0|
|jdkVersion| Provide JDK version. For example, jdk1.8.0_291|
|linuxOSVersion| Provide Oracle Linux version. For example, 7.6 in case it is Oracle Linux 7.6. </br> Supported versions 7.3, 7.4 and 7.6|
|wlsPatchURL|Provide WebLogic patch stored in your Azure subscription storage account container ( SAS URI ).  Make sure URL is accessible. </br> |
|opatchURL|Provide OPatch stored in your Azure subscription storage account container ( SAS URI ).  Make sure URL is accessible. </br> |

## Usage with Azure CLI
**Creating image builder template**

az group deployment create --resource-group *your_resource_group_name* --template-uri *https://raw.githubusercontent.com/sanjaymantoor/wls-image-builder/master/mainTemplate.json* --parameters *parameters.json*

Image template created based on "wls"${wlsVersion}-${jdkVersion}-ol${linuxOSVersion} format.

For example, </br>

wlsVersion=14.1.1.0.0
jdkVersion=jdk1.8.0_291
linuxOSVersion=7.6

`az group deployment create --resource-group  wls1411-rg --template-uri https://raw.githubusercontent.com/sanjaymantoor/wls-image-builder/master/mainTemplate.json --parameters parameters.json`

Image template name created is *wls14.1.1.0.0-jdk1.8.0_291-ol7.6* under resource group *wls1411-rg*

**Starting the image build**

az resource invoke-action --resource-group *your_resource_group_name* --resource-type  Microsoft.VirtualMachineImages/imageTemplates -n *template_name_created*  --action Run

For example, </br>

`az resource invoke-action --resource-group wls1411-rg --resource-type  Microsoft.VirtualMachineImages/imageTemplates -n wls14.1.1.0.0-jdk1.8.0_291-ol7.6 --action Run`

Image builder action run will take few minutes to complete. Azure image builder creates resource group with prefix *IT-your_resource_group_name*.

At the end of execution, action run will provide VHD location URL, which is available under image builder created resource group with prefix *IT-your_resource_group_name* storage account under container *vhds* .

VHD file needs to be moved or copied to safe storage locaton for further usage like for creating market place offer.

## Validate successful deployment 

### Upon successful completion of Creating the image builder template

    `"provisioningState": "Succeeded",
    "templateHash": "10808740392366687826",
    "templateLink": {
      "contentVersion": "1.0.0.0",
      "id": null,
      "queryString": null,
      "relativePath": null,
      "uri": "https://raw.githubusercontent.com/sanjaymantoor/arm-wls-image-builder/master/mainTemplate.json"
    },`

**At azure portal**

![image](https://user-images.githubusercontent.com/36834780/149988999-c83f1ff6-4ac7-434c-ac12-727f95d5f3a4.png)

### Upon successful completion of image builder action run

`{
  "endTime": "2022-01-18T17:22:13.5424586Z",
  "name": "7EF5EA1B-8927-4B2A-8045-6F8CF0158D60",
  "startTime": "2022-01-18T17:00:54.7Z",
  "status": "Succeeded"
}`

**At azure portal**

![image](https://user-images.githubusercontent.com/36834780/149989766-ad92f708-fc87-49dc-8beb-c6c6aea333c5.png)
