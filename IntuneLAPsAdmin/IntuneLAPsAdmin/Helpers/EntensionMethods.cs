using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Helpers
{
    public static class EntensionMethods
    {
        public static string HostnameUpdate(this string hostname)
        {
            if (hostname != null && hostname != "")
            {
                hostname = hostname.ToUpper();

                return hostname;
            }
            else
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
