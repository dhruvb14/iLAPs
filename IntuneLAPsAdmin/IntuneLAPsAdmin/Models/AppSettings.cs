using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace IntuneLAPsAdmin.Models
{
    [JsonObject("AppSettings")]
    public class AppSettings
    {
        [JsonProperty("ApiUrl")]
        public string ApiUrl { get; set; }
        [JsonProperty("SASToken")]
        public string SASToken { get; set; }
        [JsonProperty("AzureTable")]
        public string AzureTable { get; set; }
        [JsonProperty("PasswordResetTable")]
        public string PasswordResetTable { get; set; }
        [JsonProperty("LogTable")]
        public string LogTable { get; set; }
        [JsonProperty("SecretKey")]
        public string SecretKey { get; set; }
        [JsonProperty("AutomaticPasswordResetInHours")] 
        public int AutomaticPasswordResetInHours { get; set; }
        [JsonProperty("MachineNamePrefix")] 
        public string MachineNamePrefix { get; set; }
    }
}
