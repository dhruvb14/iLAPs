using Microsoft.Azure.Cosmos.Table;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Models
{
    public class LogResult : TableStorageBaseModel
    {
        public List<Log> value { get; set; }
    }
    public class Log: TableEntity
    {
        public string Username { get; set; }
        public string Hostname { get; set; }
        public string Action { get; set; }
        public DateTime ActionTime { get; set; }
        public string Query { get; set; }
    }
}
