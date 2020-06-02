using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Helpers
{
    public static class EntensionMethods
    {
        public static string HostnamePrefix(this string hostname, string userprefix)
        {
            if (hostname != null && hostname != "")
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
                return null;
            }
        }
        public static DateTime Trim(this DateTime dt)
        {
            return new DateTime(dt.Year, dt.Month, dt.Day, dt.Hour, dt.Minute, 0, 0, dt.Kind);
        }
    }
}
