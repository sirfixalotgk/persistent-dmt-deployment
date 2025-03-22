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

# Call functions to perform actions
Generate-Token
Generate-Issuer
Update-ConfigFiles

docker pull
docker up -d --build vault
$global:initData = (Invoke-RestMethod -Uri http://localhost:8200/v1/sys/init -Method GET)
$initData
