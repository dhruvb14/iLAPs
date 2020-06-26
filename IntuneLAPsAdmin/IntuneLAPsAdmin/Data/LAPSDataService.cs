using IntuneLAPsAdmin.Models;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Options;
using Sotsera.Blazor.Toaster;
using IntuneLAPsAdmin.Helpers;
using IntuneLAPsAdmin.Interfaces;
using System;
using System.Globalization;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;


namespace IntuneLAPsAdmin.Data
{
    public class LAPSDataService : ILAPSDataService
    {
        private readonly IOptions<AppSettings> _settings;
        protected readonly IToaster _toaster;
        protected readonly IRestClient http;
        protected readonly ILoggerDataService log;
        protected readonly DecryptStringData helper;
        private IHttpContextAccessor _contextAccessor;

        public LAPSDataService(IOptions<AppSettings> settings, IRestClient rest, IToaster toaster, IHttpContextAccessor contextAccessor, ILoggerDataService logger)
        {
            _toaster = toaster;
            _settings = settings;
            http = rest;
            helper = new DecryptStringData();
            _contextAccessor = contextAccessor;
            log = logger;
        }
        public async Task<AdminPasswords> GetAsync(string HostNameFilter, string AccountNameFilter)
        {
            string SerialNumber = null;
            HostNameFilter = HostNameFilter.HostnameUpdate();
            var LogMessage = $"Perform Search for Hostname: {HostNameFilter}";
            var Url = $"?$filter=Hostname%20eq%20'{HostNameFilter}'";
            if (!string.IsNullOrEmpty(AccountNameFilter))
            {
                Url += $"%20and%20Account%20eq%20'{AccountNameFilter}'";
                LogMessage += $" and Account Name: {AccountNameFilter}";
            }
            Url += "&$top=100";
            log.UpdateAccessLogs(LoggingAction.SearchForMachine, LogMessage, HostNameFilter);
            var results = await http.GetAdminJsonAsync<AdminPasswords>(Url);
            if (results.value.Count() == 0)
            {
                _toaster.Error($"The Machine you are requesting could not be found.");
            }
            else
            {
                SerialNumber = results.value.FirstOrDefault().SerialNumber;
            }

            while (!string.IsNullOrEmpty(results.NextPartitionKey) && !string.IsNullOrEmpty(results.NextRowKey))
            {
                results = await GetAdditionalResultsAsync(HostNameFilter, AccountNameFilter, results);
            }
            // Add next password change information if Reset Password was triggered. Otherwise fallback to next scheduled auto change
            if (!string.IsNullOrEmpty(SerialNumber))
            {

                Url = $"(PartitionKey='{HostNameFilter}',RowKey='{SerialNumber}')?";

                var result = await http.GetResetJsonAsync<ResetPassword>(Url, true);
                if (result != null)
                {
                    if (result.NeedsReset)
                    {
                        results.PasswordResetDate = DateTime.Parse(result.ResetRequestedDate);
                        return results;
                    }
                }
            }
            results.PasswordResetDate = results.value.OrderByDescending(x => x.PasswordChanged).FirstOrDefault().PasswordNextChange;
            return results;
        }
        public async Task<AdminPasswords> GetAdditionalResultsAsync(string HostNameFilter, string AccountNameFilter, AdminPasswords currentViewModel)
        {
            HostNameFilter = HostNameFilter.ToUpper();
            var Url = $"?$filter=Hostname%20eq%20'{HostNameFilter}'";
            if (!string.IsNullOrEmpty(AccountNameFilter))
            {
                Url += $"%20and%20Account%20eq%20'{AccountNameFilter}'";
            }
            Url += "&$top=100";
            Url += $"&NextPartitionKey={currentViewModel.NextPartitionKey}&NextRowKey={currentViewModel.NextRowKey}";
            var results = await http.GetAdminJsonAsync<AdminPasswords>(Url);
            if (results.value.Count() != 0)
            {
                foreach (var result in results.value)
                {
                    currentViewModel.value.Add(result);
                }
            }
            // Add back any additional paging information to original viewmodel
            currentViewModel.NextPartitionKey = results.NextPartitionKey;
            currentViewModel.NextRowKey = results.NextRowKey;
            return currentViewModel;
        }
        public async Task<AdminPasswordsResults> DecryptPassword(AdminPasswordsResults currentViewModel)
        {
            currentViewModel = DecryptPasswordNoReset(currentViewModel);
            await ResetPasswordAsync(currentViewModel.Hostname, currentViewModel.SerialNumber);
            return currentViewModel;
        }
        public AdminPasswordsResults DecryptPasswordNoReset(AdminPasswordsResults currentViewModel)
        {
            currentViewModel.DecryptedPassword = helper.GetDecryptString(currentViewModel.Password, _settings.Value.SecretKey);
            log.UpdateAccessLogs(LoggingAction.ViewPassword, $"{currentViewModel.Hostname} decrypted", currentViewModel.Hostname);
            return currentViewModel;
        }

        public async Task<ResetPassword> ResetPasswordAsync(string Hostname, string SerialNumber)
        {
            Hostname = Hostname.HostnameUpdate();
            var Url = $"(PartitionKey='{Hostname}',RowKey='{SerialNumber}')?";

            var result = await http.GetResetJsonAsync<ResetPassword>(Url, true);
            if (result != null)
            {
                if (result.NeedsReset)
                {
                    PasswordResetToast(Hostname, result.ResetRequestedDate);
                }
                else
                {
                    result.NeedsReset = true;
                    result.ResetRequestedDate = DateTime.UtcNow.AddHours(_settings.Value.AutomaticPasswordResetInHours).ToString("yyyy-MM-ddTHH:mm:ssZ");
                    var updateResult = await http.PutResetJsonAsync<ResetPassword>(Url, result);
                    if (updateResult == null)
                    {
                        PasswordResetToast(Hostname, result.ResetRequestedDate);
                    }
                }
            }
            else
            {
                var resetRequest = new ResetPassword()
                {
                    NeedsReset = true,
                    PartitionKey = Hostname,
                    RowKey = SerialNumber,
                    ResetRequestedDate = DateTime.UtcNow.AddHours(_settings.Value.AutomaticPasswordResetInHours).ToString("yyyy-MM-ddTHH:mm:ssZ")
                };
                result = await http.PutResetJsonAsync<ResetPassword>(Url, resetRequest);
                PasswordResetToast(Hostname, resetRequest.ResetRequestedDate);
            }
            log.UpdateAccessLogs(LoggingAction.ResetPassword, $"{Hostname} password reset requested", Hostname);
            // Add back any additional paging information to original viewmodel
            return result;
        }

        public void PasswordResetToast(string Hostname, string ResetRequestedDate)
        {
            _toaster.Success($"This admin password for {Hostname} will automatically reset at {DateTime.Parse(ResetRequestedDate).ToString("MM/dd/yyyy hh:mm tt")}", null, options =>
            {
                options.RequireInteraction = true;
            });
        }
        public async Task<DEMPasswords> GetDemPasswordsAsync()
        {
            var Url = "?$top=100";
            //log.UpdateAccessLogs(LoggingAction.SearchForMachine, LogMessage, HostNameFilter);
            var results = await http.GetDEMJsonAsync<DEMPasswords>(Url);
            if (results.value.Count() == 0)
            {
                _toaster.Error($"There was an error getting DEM Passwords");
            }

            while (!string.IsNullOrEmpty(results.NextPartitionKey) && !string.IsNullOrEmpty(results.NextRowKey))
            {
                results = await GetAdditionalDEMResultsAsync(results);
            }
            return results;
        }
        public async Task<DEMPasswords> GetAdditionalDEMResultsAsync(DEMPasswords currentViewModel)
        {
            var Url = "?$top=100";
            Url += $"&NextPartitionKey={currentViewModel.NextPartitionKey}&NextRowKey={currentViewModel.NextRowKey}";
            var results = await http.GetDEMJsonAsync<DEMPasswords>(Url);
            if (results.value.Count() != 0)
            {
                foreach (var result in results.value)
                {
                    currentViewModel.value.Add(result);
                }
            }
            // Add back any additional paging information to original viewmodel
            currentViewModel.NextPartitionKey = results.NextPartitionKey;
            currentViewModel.NextRowKey = results.NextRowKey;
            return currentViewModel;
        }
        public DEMPasswordResults DecryptDEMPasswordNoReset(DEMPasswordResults currentViewModel)
        {
            currentViewModel.DecryptedPassword = helper.GetDecryptString(currentViewModel.Password, _settings.Value.SecretKey);
            log.UpdateAccessLogs(LoggingAction.ViewDEMPassword, $"{currentViewModel.AccountEmailAddress}'s Password decrypted");
            return currentViewModel;
        }
    }
}
