using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Microsoft.Azure.Services.AppAuthentication;
using Microsoft.Azure.KeyVault;
using Microsoft.Azure.KeyVault.Models;
using Microsoft.Azure.Management.ResourceManager.Fluent.Authentication;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using Microsoft.Azure.Management.Fluent;
using Microsoft.Azure.Management.KeyVault.Fluent.Models;
using Newtonsoft.Json.Linq;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Flurl.Http;
using Flurl;

namespace EnableVmMSI
{
  
    public sealed class AzureResourceManager
    {
        
        private KeyVaultClient _kv;        
        private ClientCredential _clientCred;
        private IAzure _azure;

        public AzureResourceManager(AzureResourceInformation resourceId, KeyVaultInformation kvInfo)
        {
 
            Initialize(resourceId, kvInfo).Wait();
            AddIMSIToVMAsync(resourceId, kvInfo).Wait();
            
        }

        private async Task Initialize(AzureResourceInformation resourceInfo, KeyVaultInformation vault)
        {

            //AzureServiceTokenProvider azureServiceTokenProvider = new AzureServiceTokenProvider();
            var azureServiceTokenProvider = new AzureServiceTokenProvider();
            _kv = new KeyVaultClient(new KeyVaultClient.AuthenticationCallback(azureServiceTokenProvider.KeyVaultTokenCallback));

            string _id = (await _kv.GetSecretAsync(vault.KeyVaultUri, vault.KV_SecretName_ServicePrinciple)).Value;
            string _cred = (await _kv.GetSecretAsync(vault.KeyVaultUri, vault.KV_SecretName_ServicePrinciplePwd)).Value;

            resourceInfo.LabResourceGroup = ParseLabResourceGroup(resourceInfo.ResourceUri);

            AzureCredentials _azureCred = SdkContext.AzureCredentialsFactory.FromServicePrincipal(
                _id, _cred, resourceInfo.TenantId, AzureEnvironment.AzureGlobalCloud);

            _azure = Azure.Authenticate(_azureCred).WithSubscription(resourceInfo.SubscriptionId);

            _clientCred = new ClientCredential(_id, _cred);

        }

        private string ParseLabResourceGroup(string resourceId)
        {
            int first = (resourceId.IndexOf("resourceGroups/") + 15);
            return resourceId.Substring(first, resourceId.IndexOf("/", first) - first);

        }

        public async Task AddIMSIToVMAsync(AzureResourceInformation resourceInfo, KeyVaultInformation vault)
        {
            List<string> allVms = await GetArtifactInfoAsync(resourceInfo);

            if (allVms.Count > 0)
            {
                foreach (string vmResourceId in allVms)
                {
                    if (!string.IsNullOrWhiteSpace(vmResourceId))
                    {
                        try
                        {
                            var vm = await _azure.VirtualMachines.GetByIdAsync(vmResourceId);

                            if (!vm.IsManagedServiceIdentityEnabled)
                            {
                                await vm.Update().WithSystemAssignedManagedServiceIdentity().ApplyAsync();

                            }

                            var _keyVault = _azure.Vaults.GetByResourceGroup(vault.KeyVaultResourceGroup, vault.KeyVaultName);
                            await _keyVault.Update()
                                .DefineAccessPolicy()
                                    .ForObjectId(vm.SystemAssignedManagedServiceIdentityPrincipalId)
                                    .AllowSecretPermissions(SecretPermissions.Get)
                                .Attach()
                                .ApplyAsync();
                            // Remove after 30 min async
                            RemoveAccess(vm, _keyVault);
                        }
                        catch (Exception e) { }
                    }
                }
            }
        }


        private async Task<List<string>> GetArtifactInfoAsync(AzureResourceInformation resourceInfo)
        {
            List<string> computeId = new List<string>();
            var context = new AuthenticationContext($"https://login.windows.net/{resourceInfo.TenantId}", false);
            var token = await context.AcquireTokenAsync("https://management.azure.com/", _clientCred);

            string[] expandProperty = new string[] {"$expand=properties($expand=artifacts)", "api-version=2018-10-15-preview"};

            var response = await new Url($"https://management.azure.com/subscriptions/{resourceInfo.SubscriptionId}/resourceGroups/{resourceInfo.LabResourceGroup}/providers/Microsoft.DevTestLab/labs/{resourceInfo.LabName}/virtualmachines")
                    .WithOAuthBearerToken(token.AccessToken)
                    .SetQueryParams(expandProperty)
                    .GetStringAsync();

            // Find the vm with the artifact has a status to Installing
            JObject vmsObject = JObject.Parse(response);
            JArray vms = (JArray)vmsObject.SelectToken("value");

            foreach (JToken vm in vms.Children())
            {
                var targetVM = vm.SelectToken("$..artifacts[?(@.artifactTitle == '"+ resourceInfo.ArtifactTitle +"' && @.status == 'Installing')]", false);

                if ((targetVM != null) && (targetVM.HasValues)) 
                {
                    computeId.Add(vm.SelectToken("properties.computeId").Value<string>());
                }

            }
            return computeId; 
        }

        private async Task RemoveAccess(Microsoft.Azure.Management.Compute.Fluent.IVirtualMachine vm, Microsoft.Azure.Management.KeyVault.Fluent.IVault vault )
        {
            TimeSpan timeSpan = new TimeSpan(0, 3, 0);
            await Task.Delay(timeSpan);
            await vault.Update()
                .WithoutAccessPolicy(vm.SystemAssignedManagedServiceIdentityPrincipalId).ApplyAsync();
                    
            await vm.Update().WithoutSystemAssignedManagedServiceIdentity().ApplyAsync();
        }
    }

    public class AzureResourceInformation
    {
        public string TenantId { get; set; }
        public string SubscriptionId { get; set; }
        public string ResourceUri { get; set; }
        public string LabName { get; set; }
        public string LabResourceGroup { get; set; }
        public string ArtifactTitle { get; set; }
        public string ArtifactFolder { get; set; }
    }

    public class KeyVaultInformation
    {
        public string KeyVaultName { get; set; }
        public string KeyVaultUri { get; set; }
        public string KeyVaultResourceGroup { get; set; }
        public string KV_SecretName_ServicePrinciple { get; set; }
        public string KV_SecretName_ServicePrinciplePwd { get; set; }
    }
}
