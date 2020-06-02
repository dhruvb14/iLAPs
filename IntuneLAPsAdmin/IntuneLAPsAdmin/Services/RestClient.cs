using IntuneLAPsAdmin.Interfaces;
using IntuneLAPsAdmin.Models;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using Sotsera.Blazor.Toaster;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Services
{
    public class RestClient: IRestClient
    {
        protected readonly HttpClient _httpClient;
        protected readonly IToaster _toaster;
        private readonly IOptions<AppSettings> _settings;

        public RestClient(IHttpClientFactory clientFactory, IToaster toaster, IOptions<AppSettings> settings)
        {
            _httpClient = clientFactory.CreateClient("iLAPs-Client");
            _toaster = toaster;
            _settings = settings;
            _httpClient.DefaultRequestHeaders.Add("Accept", "application/json;odata=nometadata");
        }

        public string GetApiUrl()
        {
            return _httpClient.BaseAddress.AbsoluteUri;
        }


        #region HTTPHelperOverrides

        public async Task<T> GetAdminJsonAsync<T>(string url, bool supressToast = false)
        {
            return await SendAsync<T>(HttpMethod.Get, url, _settings.Value.AzureTable, null, supressToast);
        }
        public async Task<T> GetResetJsonAsync<T>(string url, bool supressToast = false)
        {
            return await SendAsync<T>(HttpMethod.Get, url, _settings.Value.PasswordResetTable, null, supressToast);
        }
        public async Task<T> GetLogJsonAsync<T>(string url, bool supressToast = false)
        {
            return await SendAsync<T>(HttpMethod.Get, url, _settings.Value.LogTable, null, supressToast);
        }
        public async Task<T> PutResetJsonAsync<T>(string url, object value)
        {
            return await SendAsync<T>(HttpMethod.Put, url, _settings.Value.PasswordResetTable, value);
        }
        public async Task<T> PutLogJsonAsync<T>(string url, object value)
        {
            return await SendAsync<T>(HttpMethod.Put, url, _settings.Value.LogTable, value);
        }
        public async Task<T> PostJsonAsync<T>(string url, object value)
        {
            return await SendAsync<T>(HttpMethod.Post, url, _settings.Value.AzureTable, value);
        }
        public async Task<T> DeleteJsonAsync<T>(string url)
        {
            return await SendAsync<T>(HttpMethod.Delete, url, _settings.Value.AzureTable);
        }

        public async Task<T> GetFileAsync<T>(string url)
        {
            return await SendAsync<T>(HttpMethod.Get, url, _settings.Value.AzureTable);
        }

        public async Task<T> PostFileAsync<T>(string url, object content)
        {
            return await SendAsync<T>(HttpMethod.Post, url, _settings.Value.AzureTable, content);
        }

        public async Task<T> DeleteFileAsync<T>(string url)
        {
            return await SendAsync<T>(HttpMethod.Delete, url, _settings.Value.AzureTable);
        }

        private async Task<T> SendAsync<T>(HttpMethod httpMethod, string url, string AzureTable, object value = null, bool supressToast = false)
        {
            try
            {
                url = $"{AzureTable}{url}{_settings.Value.SASToken.Replace("?","&")}";
                HttpContent requestContent;
                if (value == null)
                {
                    requestContent = null;
                }
                else if (value is StreamContent)
                {
                    requestContent = (StreamContent)value;
                }
                else
                {
                    requestContent = new StringContent(JsonConvert.SerializeObject(value), Encoding.UTF8, "application/json");
                }

                using (var request = new HttpRequestMessage(httpMethod, url) { Content = requestContent })
                using (var response = await _httpClient.SendAsync(request))
                {
                    string errorMessage;
                    var content = await response.Content.ReadAsStringAsync();

                    if (response.IsSuccessStatusCode)
                    {
                        //if its a string or other primitive type. just return it. otherwise, assume its a view model and deserialize the json
                        Type type = typeof(T);
                        if (type.IsPrimitive || type.Equals(typeof(string))) return (T)Convert.ChangeType(content, typeof(T));
                        var data = JsonConvert.DeserializeObject<T>(content);
                        // Below code is to support pagination of Table Storage
                        if (typeof(T).IsSubclassOf(typeof(TableStorageBaseModel)))
                        {
                            (data as TableStorageBaseModel).NextPartitionKey = response.Headers.TryGetValues("x-ms-continuation-NextPartitionKey", out var NextPartitionKey) ? NextPartitionKey.FirstOrDefault() : null;
                            (data as TableStorageBaseModel).NextRowKey = response.Headers.TryGetValues("x-ms-continuation-NextRowKey", out var NextRowKey) ? NextRowKey.FirstOrDefault() : null;
                        }
                        return data;
                    }

                    if (!supressToast)
                    {
                        errorMessage = content;

                        switch (response.StatusCode)
                        {
                            case System.Net.HttpStatusCode.BadRequest:
                                _toaster.Error($"There was a problem with your request: {errorMessage}");
                                break;
                            case System.Net.HttpStatusCode.Unauthorized:
                                _toaster.Error($"You are no longer logged in. Please refresh the page and try again.");
                                break;
                            case System.Net.HttpStatusCode.Forbidden:
                                _toaster.Error($"You do not have permission to perform the request. Please contact a system administrator if you believe this is an error.");
                                break;
                            case System.Net.HttpStatusCode.NotFound:
                                _toaster.Error($"The information you are requesting could not be found.");
                                break;
                            case System.Net.HttpStatusCode.InternalServerError:
                                _toaster.Error("An error occurred during your request. Please try again or contact a system administrator if it continues.");
#if DEBUG
                                Console.WriteLine(errorMessage);
#endif
                                break;
                            default:
                                break;
                        }
                    }

                    return default;
                }
            }
            catch (Exception e)
            {
                _toaster.Error("An error occurred during your request. Please try again or contact a system administrator if it continues.");
                Console.WriteLine(e);
                return default;
            }
        }

        #endregion HTTPHelperOverrides
    }
}
