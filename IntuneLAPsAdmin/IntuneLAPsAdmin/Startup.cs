using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.AzureAD.UI;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.HttpsPolicy;
using Microsoft.AspNetCore.Mvc.Authorization;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using IntuneLAPsAdmin.Data;
using IntuneLAPsAdmin.Services;
using Sotsera.Blazor.Toaster.Core.Models;
using IntuneLAPsAdmin.Models;
using System.IO;
using IntuneLAPsAdmin.Interfaces;
using IntuneLAPsAdmin.Infrastructure;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.TokenCacheProviders.Distributed;
using Microsoft.Identity.Web.TokenCacheProviders.InMemory;
using Microsoft.Extensions.Hosting;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.Identity.Web.UI;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;

namespace IntuneLAPsAdmin
{
    public class Startup
    {
        public Startup(IConfiguration configuration, IWebHostEnvironment env)
        {
#if DEBUG
            IConfigurationBuilder builder = new ConfigurationBuilder()
               .SetBasePath(Directory.GetCurrentDirectory())
               .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
               .AddJsonFile($"appsettings.{env.EnvironmentName}.json", optional: false, reloadOnChange: true)
               .AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true) // This must be loaded last since it will overrite the environment one
               .AddEnvironmentVariables();

            this.Configuration = builder.Build();
#else
            Configuration = configuration;
#endif
        }
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        // This method gets called by the runtime. Use this method to add services to the container.
        // For more information on how to configure your application, visit https://go.microsoft.com/fwlink/?LinkID=398940
        public void ConfigureServices(IServiceCollection services)
        {
            //services.AddAuthentication(AzureADDefaults.AuthenticationScheme)
            //    .AddAzureAD(options => Configuration.Bind("AzureAd", options));

            //services.AddControllersWithViews(options =>
            //{
            //    var policy = new AuthorizationPolicyBuilder()
            //        .RequireAuthenticatedUser()
            //        .Build();
            //    options.Filters.Add(new AuthorizeFilter(policy));
            //});

            services.Configure<CookiePolicyOptions>(options =>
            {
                // This lambda determines whether user consent for non-essential cookies is needed for a given request.
                options.CheckConsentNeeded = context => true;
                options.MinimumSameSitePolicy = SameSiteMode.Unspecified;
                // Handling SameSite cookie according to https://docs.microsoft.com/en-us/aspnet/core/security/samesite?view=aspnetcore-3.1
                options.HandleSameSiteCookieCompatibility();
            });

            services.AddOptions();

            services.AddSignIn(Configuration);

            // Token acquisition service based on MSAL.NET
            // and chosen token cache implementation
            services.AddWebAppCallsProtectedWebApi(Configuration, new string[] { Constants.ScopeUserRead })
               .AddInMemoryTokenCaches();

            /*
               // or use a distributed Token Cache by adding 
                           .AddDistributedTokenCaches();

               // and then choose your implementation. 
               // See https://docs.microsoft.com/en-us/aspnet/core/performance/caching/distributed?view=aspnetcore-2.2#distributed-memory-cache

               // For instance the distributed in memory cache
                services.AddDistributedMemoryCache()

               // Or a Redis cache
               services.AddStackExchangeRedisCache(options =>
                    {
                        options.Configuration = "localhost";
                        options.InstanceName = "SampleInstance";
                    });

               // Or even a SQL Server token cache
               services.AddDistributedSqlServerCache(options =>
                {
                    options.ConnectionString = 
                        _config["DistCache_ConnectionString"];
                    options.SchemaName = "dbo";
                    options.TableName = "TestCache";
                });
            */
            // Add Graph
            services.AddGraphService(Configuration);

            services.AddControllersWithViews(options =>
            {
                var policy = new AuthorizationPolicyBuilder()
                    .RequireAuthenticatedUser()
                    .Build();
                options.Filters.Add(new AuthorizeFilter(policy));
            }).AddMicrosoftIdentityUI();
            services.Configure<AppSettings>(Configuration.GetSection("AppSettings"));
            var appSettings = Configuration.GetSection("AppSettings").Get<AppSettings>();

            services.AddHttpClient<RestClient>("iLAPs-Client", client =>
            {
                client.BaseAddress = new Uri(appSettings.ApiUrl);
            });

            services.AddToaster(config =>
            {
                //example customizations
                config.PositionClass = Defaults.Classes.Position.TopRight;
                config.PreventDuplicates = true;
                config.NewestOnTop = false;
            });
            services.AddHttpContextAccessor();

            services.AddScoped<IRestClient, RestClient>();
            services.AddScoped<ILoggerDataService, LoggerDataService>();
            services.AddScoped<ILAPSDataService, LAPSDataService>();
            //services.AddScoped<IOptions<WebOptions>>();
            //services.AddScoped<ITokenAcquisition>(); 
            services.AddScoped<AuthService>();
            services.AddRazorPages();
            services.AddServerSideBlazor();
            //services.AddSingleton<iLAPSDataService>();
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }

            app.UseHttpsRedirection();
            app.UseStaticFiles();
            app.UseCookiePolicy();

            app.UseRouting();

            app.UseAuthentication();
            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
                endpoints.MapBlazorHub();
                endpoints.MapFallbackToPage("/_Host");
            });
        }
    }
}
