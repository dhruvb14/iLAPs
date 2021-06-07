using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Models
{
    public class TableStorageBaseModel
    {
        public string NextPartitionKey { get; set; }
        public string NextRowKey { get; set; }
        public DateTimeOffset PasswordResetDate { get; set; }
        public string OriginalHostName { get; set; }
        public string OriginalUserName { get; set; }
    }
}
