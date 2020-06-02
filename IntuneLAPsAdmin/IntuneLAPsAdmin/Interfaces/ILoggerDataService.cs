using IntuneLAPsAdmin.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Interfaces
{
    public interface ILoggerDataService
    {
        public void UpdateAccessLogs(string UserAction, string UserQuery, string InputHostname = "N/A");
        Task<LogResult> GetAsync(string HostNameFilter, string UserNameFilter);
    }
}
