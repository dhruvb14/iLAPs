using IntuneLAPsAdmin.Interfaces;
using IntuneLAPsAdmin.Models;
using Microsoft.AspNetCore.Components;
using Microsoft.Extensions.Options;
using Microsoft.JSInterop;
using Sotsera.Blazor.Toaster;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Helpers
{
    public abstract class BlazorPageBase : ComponentBase
    {
        [Inject]
        protected IRestClient RestClient { get; set; }
        [Inject]
        protected IAuthService AuthService { get; set; }
        [Inject]
        protected ILAPSDataService Service { get; set; }
        [Inject]
        protected ILoggerDataService Logs { get; set; }
        [Inject]
        protected IToaster Toaster { get; set; }
        [Inject]
        public NavigationManager NavigationManager { get; set; }
        [Inject]
        public IJSRuntime JSRuntime { get; set; }
        [Inject]
        public IOptions<AppSettings> InjectedAppSettings { get; set; }
    }
}
