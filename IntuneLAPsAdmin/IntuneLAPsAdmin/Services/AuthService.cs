using Graph = Microsoft.Graph;
using IntuneLAPsAdmin.Interfaces;
using Microsoft.Extensions.Options;
using Microsoft.Graph;
using Microsoft.Identity.Web;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using IntuneLAPsAdmin.Infrastructure;
using IntuneLAPsAdmin.Models;
using Newtonsoft.Json;

namespace IntuneLAPsAdmin.Services
{
    public class AuthService : IAuthService
    {
        readonly ITokenAcquisition tokenAcquisition;
        readonly WebOptions webOptions;
        readonly IOptions<AppSettings> _settings;
        public bool IsLoggedIn { get; set; } = true;
        List<Group> CurrentGroupsFromGraph { get; set; } = new List<Group>();
        public AuthService(ITokenAcquisition tokenAcquisition,
                              IOptions<WebOptions> webOptionValue, IOptions<AppSettings> settings)
        {
            this.tokenAcquisition = tokenAcquisition;
            this.webOptions = webOptionValue.Value;
            this._settings = settings;
        }
        private string[] GetDemGroups()
        {
            var AdminGroups = _settings.Value.DEMAdminGroups;
            var SuperAdminGroups = _settings.Value.DEMSuperAdminGroups;
            string[] ReturnedGroups;
            if (string.IsNullOrEmpty(AdminGroups))
            {
                ReturnedGroups = JsonConvert.DeserializeObject<string[]>("['']");
            }
            else
            {
                ReturnedGroups = JsonConvert.DeserializeObject<string[]>(AdminGroups);
            }
            if (!string.IsNullOrEmpty(SuperAdminGroups))
            {
                var TempSuperAdminGroups = JsonConvert.DeserializeObject<string[]>(SuperAdminGroups);
                ReturnedGroups = ReturnedGroups.Concat(TempSuperAdminGroups).ToArray();
            }
            return ReturnedGroups;
        }
        private string[] GetDemAdminGroups()
        {
            var SuperAdminGroups = _settings.Value.DEMSuperAdminGroups;
            string[] ReturnedGroups;
            if (string.IsNullOrEmpty(SuperAdminGroups))
            {
                ReturnedGroups = JsonConvert.DeserializeObject<string[]>("['']");
            }
            else
            {
                ReturnedGroups = JsonConvert.DeserializeObject<string[]>(SuperAdminGroups);
            }
            return ReturnedGroups;
        }
        public async Task<List<Group>> GetGroups()
        {
            try
            {
                if (CurrentGroupsFromGraph.Count == 0)
                {
                    Graph::GraphServiceClient graphClient = GetGraphServiceClient(new[] { Infrastructure.Constants.ScopeUserRead });
                    var myGroups = await graphClient.Me.GetMemberGroups(false).Request().PostAsync();
                    foreach (var group in myGroups.CurrentPage)
                    {
                        var results = await graphClient.Groups.Request().Filter($"Id eq '{group}'").GetAsync();
                        CurrentGroupsFromGraph.AddRange(results.CurrentPage);
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine("Could not get groups from GRAPH" + e.ToString());
            }
            return CurrentGroupsFromGraph;
        }
        public async Task<bool> IsInDemGroupAsync()
        {
            var groups = await GetGroups();
            return groups.Any(x => GetDemGroups().Any(y => y.ToUpper() == x.DisplayName.ToUpper()));
        }
        public async Task<bool> IsInDemSuperAdminGroupAsync()
        {
            var groups = await GetGroups();
            return groups.Any(x => GetDemAdminGroups().Any(y => y.ToUpper() == x.DisplayName.ToUpper()));
        }
        public bool IsInDemGroup(string SpecificGroup)
        {
            if (CurrentGroupsFromGraph.Count > 0)
            {
                return CurrentGroupsFromGraph.Any(x => x.DisplayName.ToUpper() == SpecificGroup.ToUpper());
            }
            else
            {
                return false;
            }
        }


        private Graph::GraphServiceClient GetGraphServiceClient(string[] scopes)
        {
            return GraphServiceClientFactory.GetAuthenticatedGraphClient(async () =>
            {
                string result = await tokenAcquisition.GetAccessTokenForUserAsync(scopes);
                return result;
            }, webOptions.GraphApiUrl);
        }
    }
}
