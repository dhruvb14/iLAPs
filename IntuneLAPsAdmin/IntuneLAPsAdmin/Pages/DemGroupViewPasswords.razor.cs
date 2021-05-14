using IntuneLAPsAdmin.Helpers;
using IntuneLAPsAdmin.Models;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Pages
{
    public partial class DemGroupViewPasswordsClass : BlazorPageBase
    {
        [Parameter]
        public bool AutoResetPassword { get; set; } = true;
        [Parameter]
        public string Title { get; set; } = "View DEM Passwords";
        public List<DEMPasswordResults> results = new List<DEMPasswordResults>();
        public string HostnameFilter { get; set; }
        public string AccountNameFilter { get; set; }
        public bool ShowResults { get; set; }
        public bool IsLoading { get; set; } = false;


        protected override async Task OnInitializedAsync()
        {
            try
            {
                ShowResults = false;
                IsLoading = true;
                var allResults = await Service.GetDemPasswordsAsync();

                if (await AuthService.IsInDemSuperAdminGroupAsync())
                {
                    results = allResults.value;
                }
                else
                {
                    foreach (var result in allResults.value)
                    {
                        if (AuthService.IsInDemGroup(result.Account))
                        {
                            results.Add(result);
                        }
                    }
                }

                if (results.Count > 0)
                {
                    ShowResults = true;
                    IsLoading = false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.ToString());
            }

        }
        public void DecryptPassword(DEMPasswordResults record)
        {
            Service.DecryptDEMPasswordNoReset(record);
            StateHasChanged();
        }
    }
}
