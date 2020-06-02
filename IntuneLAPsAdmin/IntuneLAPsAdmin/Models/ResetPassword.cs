using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Models
{
    using System;
    using Newtonsoft.Json;

    public partial class ResetPassword
    {
        [JsonProperty("PartitionKey")]
        public string PartitionKey { get; set; }

        [JsonProperty("RowKey")]
        public string RowKey { get; set; }

        [JsonProperty("Timestamp")]
        public DateTime Timestamp { get; set; }

        [JsonProperty("NeedsReset")]
        public bool NeedsReset { get; set; }

        [JsonProperty("ResetRequestedDate")]
        public string ResetRequestedDate { get; set; }
    }
}
