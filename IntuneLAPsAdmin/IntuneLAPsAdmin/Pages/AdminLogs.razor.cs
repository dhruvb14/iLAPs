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
    public partial class AdminLogsClass : BlazorPageBase
    {
        [Parameter]
        public bool AutoResetPassword { get; set; } = true;
        public LogResult results;
        public string HostnameFilter { get; set; }
        public string Username { get; set; }
        public bool ShowResults { get; set; }

        protected override async Task OnInitializedAsync()
        {
            ShowResults = false;
            results = await Logs.GetAsync(HostnameFilter, Username);
            ShowResults = true;
        }

        public async void OnSearchCriteria()
        {
            ShowResults = false;
            results = await Logs.GetAsync(HostnameFilter, Username);

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
    }
}
