using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Threading.Tasks;
using IntuneLAPsAdmin.Models;
using Microsoft.Azure.Cosmos.Table;
using Microsoft.Azure.Documents;

namespace IntuneLAPsAdmin.Helpers
{
    public class Storage
    {
        public static CloudStorageAccount CreateStorageAccountFromConnectionString(string storageConnectionString)
        {
            CloudStorageAccount storageAccount;
            try
            {
                storageAccount = CloudStorageAccount.Parse(storageConnectionString);
            }
            catch (FormatException)
            {
                Console.WriteLine("Invalid storage account information provided. Please confirm the AccountName and AccountKey are valid in the app.config file - then restart the application.");
                throw;
            }
            catch (ArgumentException)
            {
                Console.WriteLine("Invalid storage account information provided. Please confirm the AccountName and AccountKey are valid in the app.config file - then restart the sample.");
                Console.ReadLine();
                throw;
            }

            return storageAccount;
        }
        public static async Task<AdminPasswordsResults> RetrieveEntityUsingPointQueryAsync(CloudTable table, string HostNameFilter, string AccountNameFilter)
        {
            try
            {
                HostNameFilter = HostNameFilter.HostnameUpdate();

                var query = table.CreateQuery<AdminPasswordsResults>()
                    .Where(x => x.Hostname == HostNameFilter);

                var LogMessage = $"Perform Search for Hostname: {HostNameFilter}";
                var Url = $"?$filter=Hostname%20eq%20'{HostNameFilter}'";
                if (!string.IsNullOrEmpty(AccountNameFilter))
                {
                    query = table.CreateQuery<AdminPasswordsResults>()
                    .Where(x => x.Hostname == HostNameFilter && x.Account == AccountNameFilter);
                    LogMessage += $" and Account Name: {AccountNameFilter}";
                }
                Url += "&$top=100";
                //log.UpdateAccessLogs(LoggingAction.SearchForMachine, LogMessage, HostNameFilter);


                TableOperation retrieveOperation = TableOperation.Retrieve<AdminPasswordsResults>(HostNameFilter, AccountNameFilter);
                TableResult result = await table.ExecuteAsync(retrieveOperation);
                AdminPasswordsResults customer = result.Result as AdminPasswordsResults;
                if (customer != null)
                {
                    Console.WriteLine("\t{0}\t{1}}", customer.PartitionKey, customer.RowKey);
                }

                if (result.RequestCharge.HasValue)
                {
                    Console.WriteLine("Request Charge of Retrieve Operation: " + result.RequestCharge);
                }

                return customer;
            }
            catch (StorageException e)
            {
                Console.WriteLine(e.Message);
                Console.ReadLine();
                throw;
            }
        }
    }
}
