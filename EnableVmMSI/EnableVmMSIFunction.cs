// Default URL for triggering event grid function in the local environment.
// http://localhost:7071/runtime/webhooks/EventGrid?functionName=EnableVmMSIFunction

using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Azure.EventGrid.Models;
using Microsoft.Azure.WebJobs.Extensions.EventGrid;
using Microsoft.Extensions.Logging;
using System;
using Newtonsoft.Json.Linq;
using System.Threading.Tasks;



namespace EnableVmMSI
{
    public static class EnableVmMSIFunction
    {

        [FunctionName("EnableVmMSIFunction")]
        public static void Run([EventGridTrigger]EventGridEvent eventGridEvent, ILogger log)
        {

            KeyVaultInformation djSecrets = new KeyVaultInformation();
            djSecrets.KeyVaultName = GetEnvironmentVariable("AzureKeyVaultName"); //azureKeyVaultName;
            djSecrets.KeyVaultUri = "https://" + djSecrets.KeyVaultName + ".vault.azure.net";
            djSecrets.KeyVaultResourceGroup = GetEnvironmentVariable("AzureKeyVaultResourceGroup");
            djSecrets.KV_SecretName_ServicePrinciple = GetEnvironmentVariable("AzureServicePrincipalIdSecretName");
            djSecrets.KV_SecretName_ServicePrinciplePwd = GetEnvironmentVariable("AzureServicePrincipalCredSecretName");

            AzureResourceInformation resourceId = GetVmResourceId(eventGridEvent);
            
            if (!string.IsNullOrWhiteSpace(resourceId.ResourceUri))
            {
                AzureResourceManager arm = new AzureResourceManager(resourceId, djSecrets);
            }
            log.LogInformation(eventGridEvent.Data.ToString());
        }

        private static AzureResourceInformation GetVmResourceId(EventGridEvent evnt)
        {
            AzureResourceInformation returnData = new AzureResourceInformation();

            returnData.ArtifactTitle = GetEnvironmentVariable("DevTestLabArtifact");
            returnData.ArtifactFolder = GetEnvironmentVariable("DevTestLabArtifactFolder");
            returnData.LabName = GetEnvironmentVariable("DevTestLabName");

            if (StringComparer.OrdinalIgnoreCase.Equals(evnt.EventType, "Microsoft.Resources.ResourceActionSuccess") &&
                evnt.Data is JObject data &&
                data.TryGetValue("operationName", out var operation) &&
                StringComparer.OrdinalIgnoreCase.Equals(operation.ToString(), "Microsoft.DevTestLab/labs/artifactsources/artifacts/generateArmTemplate/action"))
            {
                returnData.ResourceUri = data.SelectToken("resourceUri")?.ToString();
                returnData.TenantId = data.SelectToken("tenantId")?.ToString();
                returnData.SubscriptionId = data.SelectToken("subscriptionId")?.ToString();

                if ((!returnData.ResourceUri.Contains(returnData.ArtifactFolder)) || (!returnData.ResourceUri.Contains(returnData.LabName.ToLower())))
                {
                    returnData.ResourceUri = null;
                }
            }

            return returnData;

        }

        public static string GetEnvironmentVariable(string name)
        {
            return System.Environment.GetEnvironmentVariable(name, EnvironmentVariableTarget.Process);
        }
    }
}
