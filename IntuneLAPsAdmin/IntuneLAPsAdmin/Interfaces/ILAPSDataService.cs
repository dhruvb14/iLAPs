using IntuneLAPsAdmin.Models;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Interfaces
{
    public interface ILAPSDataService
    {
        Task<AdminPasswords> GetAsync(string HostNameFilter, string AccountNameFilter);
        Task<AdminPasswords> GetAdditionalResultsAsync(string HostNameFilter, string AccountNameFilter, AdminPasswords currentViewModel);
        Task<AdminPasswordsResults> DecryptPassword(AdminPasswordsResults currentViewModel);
        AdminPasswordsResults DecryptPasswordNoReset(AdminPasswordsResults currentViewModel);
    }
}
