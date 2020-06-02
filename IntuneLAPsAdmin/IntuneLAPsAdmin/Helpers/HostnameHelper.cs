using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Helpers
{
    public static class HostnameHelper
    {
        public static string HostnamePrefix(this string hostname, string userprefix)
        {
            if (hostname != null)
            {
                hostname = hostname.ToUpper();
                var prefix = userprefix.ToUpper();
                if (hostname.Contains(prefix))
                {
                    return hostname;
                }
                else
                {
                    return $"{prefix}{hostname}";
                }
            } else
            {
                return hostname;
            }
        }
    }
}
