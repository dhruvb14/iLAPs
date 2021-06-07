using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Models
{
    using System;
    using Microsoft.Azure.Cosmos.Table;
    using Newtonsoft.Json;
    public class AdminPasswords : TableStorageBaseModel
    {
        public List<AdminPasswordsResults> value { get; set; }
    }
    public class AdminPasswordsResults : TableEntity
    {
        [JsonProperty("PartitionKey")]
        public Guid PartitionKey { get; set; }

        [JsonProperty("RowKey")]
        public long RowKey { get; set; }

        [JsonProperty("Timestamp")]
        public DateTimeOffset Timestamp { get; set; }

        [JsonProperty("SerialNumber")]
        public string SerialNumber { get; set; }

        [JsonProperty("MachineGuid")]
        public Guid MachineGuid { get; set; }

        [JsonProperty("PublicIP")]
        public string PublicIp { get; set; }

        [JsonProperty("PasswordNextChange")]
        public DateTime PasswordNextChange { get; set; }

        [JsonProperty("SID")]
        public string Sid { get; set; }

        [JsonProperty("Hostname")]
        public string Hostname { get; set; }

        [JsonProperty("Password")]
        public string Password { get; set; }
        public string DecryptedPassword { get; set; }

        [JsonProperty("PasswordChanged")]
        public DateTime PasswordChanged { get; set; }

        [JsonProperty("Account")]
        public string Account { get; set; }

        [JsonProperty("Enabled")]
        public bool Enabled { get; set; }
    }
}
