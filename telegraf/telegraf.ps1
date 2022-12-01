# USER INFORMATION #############################################
$telegrafVersion="1.24.3_windows_amd64" # Telegraf Version
$vrocpHostname = "" # vRealize Operations Cloud Proxy Hostname
$vropsHostname = "" # vRealize Operations Hostname
$vropsUsername = "" # vRealize Operations Username
$vropsPassword = "" # vRealize Operations Password
################################################################

# const vars ###################################################
$telegrafPath = "$env:programfiles\Telegraf"
$telegrafPathD = "$telegrafPath\telegraf.d"
$telegrafExec = "$telegrafPath\telegraf.exe"
$telegrafConf = "$telegrafPath\telegraf.conf"

# download from telegraf official ##############################
wget "https://dl.influxdata.com/telegraf/releases/telegraf-$telegrafVersion.zip" -UseBasicParsing -OutFile telegraf.zip

# extract zip file #############################################
Expand-Archive .\telegraf.zip

# move to program files ########################################
Move-Item -Path .\telegraf\telegraf-* -Destination "$telegrafPath"
New-Item -Path "$telegrafPathD" -itemType Directory
Remove-Item -Path .\telegraf

# disable ssl key check when using wget ########################
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback +=
                    delegate
                    (
                        Object obj,
                        X509Certificate certificate,
                        X509Chain chain,
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
 }
[ServerCertificateValidationCallback]::Ignore()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# get initial setup file from vrealize operations cloud proxy ##
wget "https://$vrocpHostname/downloads/salt/open_source_telegraf_monitor.ps1" -UseBasicParsing -OutFile initial_setup.ps1

# get vrealize opeartions token ################################
$headers = @{}
$headers["Content-Type"] = "application/json"
$headers["Accept"] = "application/json"
$body = "{""username"":""$vropsUsername"",""authSource"":""Local"",""password"":""$vropsPassword""}"
$resp = Invoke-WebRequest -Method POST -Uri "https://$vropsHostname/suite-api/api/auth/token/acquire" -Body $body -Headers $headers
$content = ConvertFrom-Json -InputObject $resp.Content
$token = $content.token

# running initial setup ########################################
.\initial_setup.ps1 -v "$vropsHostname" -c "$vrocpHostname" -t "$token" -d "$telegrafPathD" -e "$telegrafExec"

# register telegraf to system service ##########################
& $telegrafExec --config "$telegrafConf" --config-directory "$telegrafPathD" --service install net start telegraf
Start-Sleep 2

# start telegraf service #######################################
Start-Service -Name "telegraf"