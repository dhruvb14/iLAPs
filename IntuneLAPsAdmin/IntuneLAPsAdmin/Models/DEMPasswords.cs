using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Models
{
    public class DEMPasswords : TableStorageBaseModel
    {
        public List<DEMPasswordResults> value { get; set; }
    }
    public class DEMPasswordResults
    {

            [JsonProperty("PartitionKey")]
            public Guid PartitionKey { get; set; }

            [JsonProperty("RowKey")]
            public Guid RowKey { get; set; }

            [JsonProperty("Timestamp")]
            public DateTimeOffset Timestamp { get; set; }
            [JsonProperty("Account")]
            public string Account { get; set; }
            [JsonProperty("AccountEmailAddress")]
            public string AccountEmailAddress { get; set; }
            [JsonProperty("NeedsReset")]
            public bool NeedsReset { get; set; }
            [JsonProperty("Password")]
            public string Password { get; set; }
            
            public string DecryptedPassword { get; set; }

            [JsonProperty("ResetRequestedDate")]
            public DateTime ResetRequestedDate { get; set; }
            [JsonProperty("ScheduledNextChange")]
            public DateTime ScheduledNextChange { get; set; }
            [JsonProperty("Enabled")]
            public bool Enabled { get; set; }

    }
}
