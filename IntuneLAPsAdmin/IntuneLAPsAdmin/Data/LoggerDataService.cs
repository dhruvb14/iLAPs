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
    public class LoggerDataService : ILoggerDataService
    {
        private readonly IOptions<AppSettings> _settings;
        protected readonly IToaster _toaster;
        protected readonly IRestClient http;
        protected readonly DecryptStringData helper;
        private IHttpContextAccessor _contextAccessor;

        public LoggerDataService(IOptions<AppSettings> settings, IRestClient rest, IToaster toaster, IHttpContextAccessor contextAccessor)
        {
            _toaster = toaster;
            _settings = settings;
            http = rest;
            helper = new DecryptStringData();
            _contextAccessor = contextAccessor;
        }
        public void UpdateAccessLogs(string InputAction, string InputQuery, string InputHostname = "N/A")
        {
            string invertedTicks = string.Format("{0:D19}", DateTime.MaxValue.Ticks - DateTime.UtcNow.Ticks);
            var Url = $"(PartitionKey='ActivityLog',RowKey='{invertedTicks}')?";
            var resetRequest = new Log()
            {
                Action = InputAction,
                ActionTime = DateTime.UtcNow,
                Username = (((_contextAccessor.HttpContext?.User).Identity).Name).ToUpper(),
                Hostname = InputHostname,
                Query = InputQuery
            };
            http.PutLogJsonAsync<Log>(Url, resetRequest);
        }
        public string FilterBuilder(string HostNameFilter, string UserNameFilter)
        {
            if (!string.IsNullOrEmpty(UserNameFilter) || !string.IsNullOrEmpty(HostNameFilter))
            {
                if (!string.IsNullOrEmpty(UserNameFilter) && !string.IsNullOrEmpty(HostNameFilter))
                {
                    return $"&$filter=Hostname%20eq%20'{HostNameFilter.ToUpper()}%20and%20Username%20eq%20'{UserNameFilter.ToUpper()}'";
                }
                if (!string.IsNullOrEmpty(UserNameFilter))
                {
                    return $"&$filter=Username%20eq%20'{UserNameFilter.ToUpper()}'";
                }
                if (!string.IsNullOrEmpty(HostNameFilter))
                {
                    return $"&$filter=Hostname%20eq%20'{HostNameFilter.ToUpper()}'";
                }
            }
            return "";
        }
        public async Task<LogResult> GetAsync(string HostNameFilter, string UserNameFilter)
        {
            //var Url = "(PartitionKey='ActivityLog')?$top=100";
            var Url = "?$top=100";
            HostNameFilter = HostNameFilter.HostnameUpdate();
            Url += FilterBuilder(HostNameFilter, UserNameFilter);
            var results = await http.GetLogJsonAsync<LogResult>(Url);
            if (results.value.Count() == 0)
            {
                _toaster.Error($"The Log you are requesting could not be found.");
            }

            while (!string.IsNullOrEmpty(results.NextPartitionKey) && !string.IsNullOrEmpty(results.NextRowKey))
            {
                results = await GetAdditionalResultsAsync(HostNameFilter, UserNameFilter, results);
            }
            return results;
        }
        public async Task<LogResult> GetAdditionalResultsAsync(string HostNameFilter, string UserNameFilter, LogResult currentViewModel)
        {
            //var Url = "(PartitionKey='ActivityLog')?$top=100";
            var Url = "?$top=100";
            HostNameFilter = HostNameFilter.HostnameUpdate();
            Url += FilterBuilder(HostNameFilter, UserNameFilter);
            Url += $"&NextPartitionKey={currentViewModel.NextPartitionKey}&NextRowKey={currentViewModel.NextRowKey}";
            var results = await http.GetLogJsonAsync<LogResult>(Url);
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
    }
}
