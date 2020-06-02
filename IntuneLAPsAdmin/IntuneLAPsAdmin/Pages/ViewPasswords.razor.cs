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
    public partial class ViewPasswordsClass : BlazorPageBase
    {
        [Parameter]
        public bool AutoResetPassword { get; set; } = true;
        [Parameter]
        public string Title { get; set; } = "View Admin Passwords";
        public AdminPasswords results;
        public string HostnameFilter { get; set; }
        public string AccountNameFilter { get; set; }
        public bool ShowResults { get; set; }
        

        protected override void OnInitialized()
        {
            ShowResults = false;
        }

        public async void OnSearchCriteria()
        {
            ShowResults = false;
            results = await Service.GetAsync(HostnameFilter, AccountNameFilter);

            if (results.value.Count() != 0)
            {
                ShowResults = true;
            }
            StateHasChanged();
        }
        public void OnEnter(KeyboardEventArgs eventArgs)
        {
            if (eventArgs.Key == "Enter")
            {
                OnSearchCriteria();
            }
        }
        public void DecryptPassword(AdminPasswordsResults record)
        {
            if (AutoResetPassword)
            {
            Service.DecryptPassword(record);
            }
            else
            {
                Service.DecryptPasswordNoReset(record);
            }
            StateHasChanged();
        }
    }
}
