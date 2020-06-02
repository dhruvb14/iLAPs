using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security;
using System.Security.Cryptography;
using System.Text;

namespace IntuneLAPsAdmin.Helpers
{
    // Code from https://stackoverflow.com/a/60599652
    public class DecryptStringData
    {
        public string GetDecryptString(string EncriptData, string DecryptionKey)
        {
            try
            {
                byte[] key = Encoding.ASCII.GetBytes(DecryptionKey);
                byte[] asBytes = Convert.FromBase64String(EncriptData);
                string[] strArray = Encoding.Unicode.GetString(asBytes).Split(new[] { '|' });

                if (strArray.Length != 3) throw new InvalidDataException("input had incorrect format");

                byte[] magicHeader = HexStringToByteArray(EncriptData.Substring(0, 32));
                byte[] rgbIV = Convert.FromBase64String(strArray[1]);
                byte[] cipherBytes = HexStringToByteArray(strArray[2]);

                SecureString str = new SecureString();
                //SymmetricAlgorithm algorithm = SymmetricAlgorithm.Create(); //This for .Net 4.5
                AesManaged algorithm = new AesManaged();

                ICryptoTransform transform = algorithm.CreateDecryptor(key, rgbIV);
                using (var stream = new CryptoStream(new MemoryStream(cipherBytes), transform, CryptoStreamMode.Read))
                {
                    int numRed = 0;
                    byte[] buffer = new byte[2]; // two bytes per unicode char
                    while ((numRed = stream.Read(buffer, 0, buffer.Length)) > 0)
                    {
                        str.AppendChar(Encoding.Unicode.GetString(buffer).ToCharArray()[0]);
                    }
                }

                string secretvalue = convertToUNSecureString(str);
                return secretvalue;
            }
            catch (Exception ex)
            {
                return ex.Message;
            }

        }


        public static byte[] HexStringToByteArray(String hex)
        {
            int NumberChars = hex.Length;
            byte[] bytes = new byte[NumberChars / 2];
            for (int i = 0; i < NumberChars; i += 2) bytes[i / 2] = Convert.ToByte(hex.Substring(i, 2), 16);

            return bytes;
        }

        public static string convertToUNSecureString(SecureString secstrPassword)
        {
            IntPtr unmanagedString = IntPtr.Zero;
            try
            {
                unmanagedString = Marshal.SecureStringToGlobalAllocUnicode(secstrPassword);
                return Marshal.PtrToStringUni(unmanagedString);
            }
            finally
            {
                Marshal.ZeroFreeGlobalAllocUnicode(unmanagedString);
            }
        }


    }
}
