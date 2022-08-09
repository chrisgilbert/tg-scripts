param(
    [string]$fqdn='relays.twingate.com',
    [int]$port=443
)

function check_ssl{
    param(
        [string]$fqdn='relays.twingate.com',
        [int]$port=443
    )
    #Allow connection to sites with an invalid certificate:
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $timeoutMilliseconds = 5000

    $url="https://$fqdn"

    Write-Host `n Checking $url -f Green
     $req = [Net.HttpWebRequest]::Create($url)
     $req.Timeout = $timeoutMilliseconds
     try {$req.GetResponse() | Out-Null} catch {}


     if ($req.ServicePoint.Certificate -ne $null)
    {
        $certinfo = New-Object security.cryptography.x509certificates.x509certificate2($req.ServicePoint.Certificate)
        $certinfo | fl
        $certinfo.Extensions | where {$_.Oid.FriendlyName -like 'subject alt*'} | `
        foreach { $_.Oid.FriendlyName; $_.Format($true) }
    }
}

if(Test-NetConnection -port $port  $fqdn -InformationLevel Quiet){
    check_ssl -fqdn $fqdn -port $port   
}else{
    throw "unable to connect to FQDN '$fqdn' on port $port"
}
