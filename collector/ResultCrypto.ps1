# AES-256-CBC + HMAC-SHA256 encrypt-then-MAC for PowerShell 5.1 / .NET Framework.
# Wire format: v1.base64(IV[16] || ciphertext || HMAC[32]); MAC input is
# UTF8("v1|" + timestamp + "|" + status + "|") || IV || ciphertext.
function Protect-ResultSummary([string]$Text,[string]$At,[string]$Status,[string]$KeyHex) {
 if($KeyHex -cnotmatch '^[a-f0-9]{128}$'){throw 'Invalid result encryption key'}
 $key=New-Object byte[] 64
 for($i=0;$i -lt 64;$i++){$key[$i]=[Convert]::ToByte($KeyHex.Substring($i*2,2),16)}
 $aesKey=New-Object byte[] 32;$macKey=New-Object byte[] 32
 [Array]::Copy($key,0,$aesKey,0,32);[Array]::Copy($key,32,$macKey,0,32)
 $aes=[Security.Cryptography.Aes]::Create()
 try {
  $aes.KeySize=256;$aes.Mode=[Security.Cryptography.CipherMode]::CBC;$aes.Padding=[Security.Cryptography.PaddingMode]::PKCS7
  $aes.Key=$aesKey;$aes.GenerateIV();$iv=$aes.IV
  $enc=$aes.CreateEncryptor()
  try{$plain=[Text.Encoding]::UTF8.GetBytes($Text);$cipher=$enc.TransformFinalBlock($plain,0,$plain.Length)}finally{$enc.Dispose()}
  $prefix=[Text.Encoding]::UTF8.GetBytes("v1|$At|$Status|")
  $signed=New-Object byte[] ($prefix.Length+$iv.Length+$cipher.Length)
  [Array]::Copy($prefix,0,$signed,0,$prefix.Length);[Array]::Copy($iv,0,$signed,$prefix.Length,$iv.Length);[Array]::Copy($cipher,0,$signed,$prefix.Length+$iv.Length,$cipher.Length)
  $hmac=New-Object Security.Cryptography.HMACSHA256(,$macKey)
  try{$tag=$hmac.ComputeHash($signed)}finally{$hmac.Dispose()}
  $packet=New-Object byte[] ($iv.Length+$cipher.Length+$tag.Length)
  [Array]::Copy($iv,0,$packet,0,$iv.Length);[Array]::Copy($cipher,0,$packet,16,$cipher.Length);[Array]::Copy($tag,0,$packet,16+$cipher.Length,$tag.Length)
  return 'v1.'+[Convert]::ToBase64String($packet)
 }finally{$aes.Dispose();[Array]::Clear($key,0,$key.Length);[Array]::Clear($aesKey,0,$aesKey.Length);[Array]::Clear($macKey,0,$macKey.Length)}
}
function Protect-AutoMasResults($summary,[string]$KeyHex) {
 if(-not $summary -or -not $summary.recentResults){return}
 foreach($item in $summary.recentResults){
  $cipher=Protect-ResultSummary ([string]$item.message) ([string]$item.at) ([string]$item.status) $KeyHex
  $item.Remove('message')
  $item['encryptedMessage']=$cipher
 }
}
