#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see https://www.gnu.org/licenses/
#
#
param (
    [Parameter(Mandatory = $true, Position=0)]
    [string]$mpsCN, 
    [Parameter(Mandatory = $false, Position=1)]
    [string]$webUiUser = "admin", 
    [Parameter(Mandatory = $true, Position=2)]
    [string]$webUiPass, 
    [Parameter(Mandatory = $false, Position=3)]
    [string]$dbUser = "postgresadmin", 
    [Parameter(Mandatory = $true, Position=4)]
    [string]$dbPass
)

Function Generate-Token {
    param (
        [int]$Length = 32,
        [string]$CharacterSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    )
    $Token = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $Token += $CharacterSet[(Get-Random -Maximum $CharacterSet.Length)]
    }
    $script:kongSecret = "secret: `"$Token`""
    $script:Token = "MPS_JWT_SECRET=$Token"
    # return $Token
}

Function Generate-Issuer {
    param (
        [int]$Length = 32,
        [string]$CharacterSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    )
    $Issuer = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $Issuer += $CharacterSet[(Get-Random -Maximum $CharacterSet.Length)]
    }
    $script:kongKey = "key: $Issuer"
    $script:Issuer = "MPS_JWT_ISSUER=$Issuer"
    # return $Issuer
}

Function Prepare-Certificate {
    Try {
        Write-Host -ForegroundColor CYAN "PFX password needed to extract the certificate:"
        openssl pkcs12 -in ./$mpsCN.pfx -clcerts -nokeys -out ./$mpsCN.crt
        Write-Host -ForegroundColor CYAN "PFX password needed to extract private key and a pass phrase is required to protect the PEM key.`n(You will enter this pass phrase in the next prompt)"
        openssl pkcs12 -in ./$mpsCN.pfx -nocerts -out ./$mpsCN.key
        Write-Host -ForegroundColor CYAN "Enter the pass phrase for the private key PEM file:`n(pass phrase entered and confirmed in the previous step)"
        openssl rsa -in ./$mpsCN.key -out ./$mpsCN.key
        openssl rsa -in ./$mpsCN.key -outform PEM -out ./$mpsCN.pem
    } Catch { Write-Host -ForegroundColor YELLOW "Failed to process certificate...continuing without it."; Return }
    Try {
        If (!(Test-Path ./kong-ssl)) {
            mkdir ./kong-ssl
        }
        Move-Item *.pem ./kong-ssl/
        Move-Item *.pfx ./kong-ssl/
        Move-Item *.crt ./kong-ssl/
        Move-Item *.key ./kong-ssl/
        chmod 755 ./kong-ssl/*.*
    } Catch { Write-Host -ForegroundColor YELLOW "Failed to process certificate...continuing without it."; Return }
    Try {
        cp ./docker-compose.yml ./pre-cert-compose-file.yml
        $envCertUpdate = (Get-Content ./docker-compose.yml)
        $envCertUpdate = $envCertUpdate.Replace('# - KONG_SSL_CERT=/ssl/oAMT_WebUI_Provisioning.crt', "- KONG_SSL_CERT=/ssl/$mpsCN.crt")
        $envCertUpdate = $envCertUpdate.Replace('# - KONG_SSL_CERT_KEY=/ssl/oAMT_WebUI_Provisioning.pem', "- KONG_SSL_CERT_KEY=/ssl/$mpsCN.pem")
        Set-Content ./docker-compose.yml -Value $envCertUpdate
    } Catch { Write-Host -ForegroundColor YELLOW "Failed to process certificate...continuing without it."; Return }
}

Function Update-ConfigFiles {
    Try {
        Write-Host -ForegroundColor CYAN "Updating .env file now..."
        $envFile = (Get-Content ./.env.template)
        $envFile = $envFile.Replace('MPS_JWT_ISSUER=9EmRJTbIiIb4bIeSsmgcWIjrR6HyETqc', $Issuer)
        $envFile = $envFile.Replace('MPS_JWT_SECRET=', $Token)
        $dbPass = "POSTGRES_PASSWORD=$dbPass"
        $envFile = $envFile.Replace('POSTGRES_PASSWORD=', $dbPass)
        $webUiUser = "MPS_WEB_ADMIN_USER=$webUiUser"
        $webUiPass = "MPS_WEB_ADMIN_PASSWORD=$webUiPass"
        $envFile = $envFile.Replace('MPS_WEB_ADMIN_USER=', $webUiUser)
        $envFile = $envFile.Replace('MPS_WEB_ADMIN_PASSWORD=', $webUiPass)
        $mpsCN = "MPS_COMMON_NAME=$mpsCN"
        $envFile = $envFile.Replace('MPS_COMMON_NAME=localhost', $mpsCN)
        $envFile = $envFile.Replace('SECRETS_PATH=secret/data/', 'SECRETS_PATH=kv/data/')
        Set-Content ./.env -Value $envFile
    } Catch { Write-Host -ForegroundColor RED "Failed!"; Exit }
    Try {
        Write-Host -ForegroundColor CYAN "Updating Kong config file now..."
        $kongFile = (Get-Content ./kong.yaml)
        $kongFile = $kongFile.Replace('key: 9EmRJTbIiIb4bIeSsmgcWIjrR6HyETqc #sample key', $kongKey)
        $kongFile = $kongFile.Replace('secret:', $kongSecret)
        Set-Content ./kong.yaml -Value $kongFile
    } Catch { Write-Host -ForegroundColor RED "Failed!"; Exit }
    Write-Host -ForegroundColor GREEN "Files updated!"
}

Function Init-Vault {
    Try {
        Write-Host -ForegroundColor CYAN "Initializing Vault..."
        $initPayload = ([PSCustomObject]@{
            secret_shares = 1
            secret_threshold = 1
        } | ConvertTo-JSON)
        $global:initData = (Invoke-RestMethod -Uri http://localhost:8200/v1/sys/init -Method PUT -Body $initPayload)
        Write-Host -ForegroundColor GREEN "Vault initialized!"
    } Catch { Write-Host -ForegroundColor RED "Failed!"; EXIT }
    Try {
        Write-Host -ForegroundColor CYAN "Updating ENV file..."
        $global:vaultKey = $initData.keys_base64
        $global:vaultToken = $initData.root_token
        $envVaultFile = (Get-Content ./.env)
        $envVaultFile = $envVaultFile.Replace('VAULT_KEY=', "VAULT_KEY=$vaultKey")
        $envVaultFile = $envVaultFile.Replace('VAULT_TOKEN=', "VAULT_TOKEN=$vaultToken")
        Set-Content ./.env -Value $envVaultFile
        Write-Host -ForegroundColor GREEN "ENV updated!"
    } Catch { Write-Host -ForegroundColor RED "Failed!"; EXIT }
    Try {
        Write-Host -ForegroundColor CYAN "Un-sealing Vault..."
        $unSeal = ([PSCustomObject]@{
            key = "$vaultKey"
        } | ConvertTo-Json)
        $unsealResult = (Invoke-RestMethod http://localhost:8200/v1/sys/unseal -Method POST -Body $unSeal)
        Write-Host -ForegroundColor GREEN "Vault un-sealed!"
    } Catch { Write-Host -ForegroundColor RED "Failed!"; EXIT }
    Try {
        Write-Host -ForegroundColor CYAN "Adding KV engine..."
        $sePayload = ([PSCustomObject]@{
            type = "kv"
                options = [PSCustomObject]@{
                    version = "2"
                }   
        } | ConvertTo-JSON)
        $vaultHeader = @{ 'X-Vault-Token' = $vaultToken }
        $engineResult = (Invoke-RestMethod http://localhost:8200/v1/sys/mounts/kv -Method POST -Headers $vaultHeader -Body $sePayload)
        Write-Host -ForegroundColor GREEN "Key Value engine, enabled!"
    } Catch { Write-Host -ForegroundColor RED "Failed!"; EXIT }
}


# Execution section:
# 
# Call functions and execute specific commands initialize and configure environment
# Call function to generate random token:
Generate-Token

# Call function to generate random issuer:
Generate-Issuer

# Call function to update files with generated values:
Update-ConfigFiles

# Work with the secret vault first
Write-Host -ForegroundColor CYAN "Downloading containers and bringing up the secret vault..."
docker-compose pull
docker-compose up -d --build vault
Write-Host -ForegroundColor CYAN "Containers downloaded and Vault coming online..."

# Initialize and configure Vault
Write-Host -ForegroundColor CYAN "Holding for 5 seconds to allow Vault to reach ready state before attempting to initialize and configure..."
Start-Sleep 5
Init-Vault

Write-Host -ForegroundColor CYAN "`n`n`nTaking Vault offline to build and activate remaining containers after configuration is applied..."
docker-compose down -v
Write-Host -ForegroundColor CYAN "`nHolding for 2 seconds to allow final sync time to complete..."
Start-Sleep 2
Write-Host -ForegroundColor CYAN "`nReplacing composition file with normal operations version of the file..."
Move-Item ./docker-compose.yml ./initial-run-compose-file.yml -Force
Move-Item ./second-run-compose-file.yml ./docker-compose.yml -Force
Start-Sleep 2
If (Test-Path ./$mpsCN.pfx) {
    Write-Host -ForegroundColor CYAN "`nFound a PFX file in this directory...calling certificate processing routine..."
    Prepare-Certificate
}
Write-Host -ForegroundColor CYAN "`nBringing everything online with normal operations composition..."
docker-compose up -d --build
Write-Host -ForegroundColor GREEN "`nDone!`nPlease note the following values for the secret vault as they are required for access.`n"
Write-Host -ForegroundColor DARKYELLOW -NoNewLine "Vault Root Token: "; Write-Host -ForegroundColor MAGENTA "$vaultToken"
Write-Host -ForegroundColor DARKYELLOW -NoNewLine "Vault Unseal Key: "; Write-Host -ForegroundColor MAGENTA "$vaultKey"
Write-Host -ForegroundColor GREEN "`n`nEnjoy your deployment of the Intel(R) AMT Device Management Toolkit!`n`n"
