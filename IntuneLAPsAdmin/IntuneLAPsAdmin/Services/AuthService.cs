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
        public async Task<List<Group>> GetGroups()
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

            return CurrentGroupsFromGraph;
        }
        public async Task<bool> IsInDemGroupAsync()
        {
            var groups = await GetGroups();
            var demGroups = _settings.Value.DEMAdminGroups;
            return groups.Any(x => demGroups.Any(y => y == x.DisplayName));
        }
        public bool IsInDemGroup(string SpecificGroup)
        {
            if (CurrentGroupsFromGraph.Count > 0)
            {
                return CurrentGroupsFromGraph.Any(x => x.DisplayName == SpecificGroup);
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
