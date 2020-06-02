using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Interfaces
{
    public interface IRestClient
    {
        string GetApiUrl();
        Task<T> GetAdminJsonAsync<T>(string url, bool suppressToast = false);
        Task<T> GetLogJsonAsync<T>(string url, bool suppressToast = false);
        Task<T> GetResetJsonAsync<T>(string url, bool suppressToast = false);
        Task<T> PostJsonAsync<T>(string url, object item);
        Task<T> PutResetJsonAsync<T>(string url, object item);
        Task<T> PutLogJsonAsync<T>(string url, object item);
        Task<T> DeleteJsonAsync<T>(string url);
        Task<T> GetFileAsync<T>(string url);
        Task<T> PostFileAsync<T>(string url, object item);
        Task<T> DeleteFileAsync<T>(string url);
    }
}
