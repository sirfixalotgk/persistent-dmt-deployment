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
        $vaultKey = $initData.keys_base64
        $vaultToken = $initData.root_token
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
        Write-Host -ForegroundColor GREEN "Key Vault engine, enabled!"
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
Write-Host -ForegroundColor CYAN "Downloading Docker containers and initializing the secret store..."
docker-compose pull
docker-compose up -d --build vault
Write-Host -ForegroundColor CYAN "Containers downloaded..."

# Initialize and configure Vault
Write-Host -ForegroundColor CYAN "Holding for 5 seconds to allow Vault to reach ready state..."
Start-Sleep 5
Init-Vault

Write-Host -ForegroundColor CYAN "Taking Vault down, building and bringing all online together..."
docker-compose down -v
Write-Host -ForegroundColor CYAN "Holding for 2 seconds to allow final sync time to complete..."
Start-Sleep 2
Write-Host -ForegroundColor CYAN "Replacing composition file with normal operations variant..."
Move-Item ./docker-compose.yml ./initial-run-compose-file.yml -Force
Move-Item ./second-run-compose-file.yml ./docker-compose.yml -Force
Start-Sleep 2
Write-Host -ForegroundColor CYAN "Bringing everything up according to dependency configuration..."
docker-compose up -d --build
Write-Host -ForegroundColor GREEN "Done!"
