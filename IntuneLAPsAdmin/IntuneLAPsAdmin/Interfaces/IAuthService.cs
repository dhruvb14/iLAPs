using Microsoft.Graph;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Interfaces
{
    public interface IAuthService
    {
        Task<bool> IsInDemGroupAsync();
        bool IsInDemGroup(string SpecificGroup);
        Task<List<Group>> GetGroups();
        Task<bool> IsInDemSuperAdminGroupAsync();
    }
}
