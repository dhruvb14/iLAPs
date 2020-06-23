using Microsoft.Extensions.Options;
using Microsoft.Graph;
using Microsoft.Identity.Web;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Graph = Microsoft.Graph;
using IntuneLAPsAdmin.Infrastructure;

namespace IntuneLAPsAdmin.Services
{
    public class AuthService
    {
        readonly ITokenAcquisition tokenAcquisition;
        readonly WebOptions webOptions;
        public bool IsLoggedIn { get; set; } = true;
        public AuthService(ITokenAcquisition tokenAcquisition,
                              IOptions<WebOptions> webOptionValue)
        {
            this.tokenAcquisition = tokenAcquisition;
            this.webOptions = webOptionValue.Value;
        }
        public async Task<List<Group>> GetGroups()
        {
            Graph::GraphServiceClient graphClient = GetGraphServiceClient(new[] { Infrastructure.Constants.ScopeUserRead });
            var myGroups = await graphClient.Me.GetMemberGroups(false).Request().PostAsync();
            List<Group> CurrentGroupsFromGraph = new List<Group>();
            foreach (var group in myGroups.CurrentPage)
            {
                var results = await graphClient.Groups.Request().Filter($"Id eq '{group}'").GetAsync();
                CurrentGroupsFromGraph.AddRange(results.CurrentPage);
            }
            return CurrentGroupsFromGraph;
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
