<#
.SYNOPSIS
Устанавливает подключение к Yandex Directory API для заданной организации с использованием указанного OAuth-токена.

.DESCRIPTION
Функция `Connect-Ya360` используется для установки подключения к Yandex Directory API. При успешном подключении функция устанавливает глобальные переменные для дальнейшего использования в других функциях модуля.

.PARAMETER orgId
Обязательный параметр. Идентификатор организации, к которой вы хотите подключиться.

.PARAMETER Authorization
Обязательный параметр. OAuth-токен, который будет использоваться для аутентификации.

.EXAMPLE
Connect-Ya360 -orgId 12345 -Authorization "yourOAuthToken"

Устанавливает подключение к организации с идентификатором 12345, используя указанный OAuth-токен.

.NOTES
Автор: ruAnimus
Дата: 2023.11.07
#>
function Connect-Ya360 {
    param (
        [Parameter(Mandatory=$true)]
        $orgId,
        [Parameter(Mandatory=$true)]
        [string]$Authorization
        )
        
    $Authorization = "OAuth  $Authorization"
    
    try {
        $Uri = "https://api360.yandex.net/directory/v1/org/$orgId/users/?page=1&perPage=1"
        
        $Ya360Responce = Invoke-WebRequest $Uri `
        -Headers @{ 'Authorization' = $Authorization } `
        -Method Get `
        -UseBasicParsing `
        -TimeoutSec 120 `
        -ErrorAction Stop
        
        if ($Ya360Responce.StatusCode -ne "200") {
            Write-Error "Invoke-WebRequest выполнен, но StatusCode не 200 : $($Ya360Responce.StatusCode)"
            $global:Ya360Connected = $false
            throw
        }
        
        $global:Ya360Connected = $true
        $global:Ya360OrgID = $orgId
        $global:Ya360OAuthToken = $Authorization
        Write-Host "Подключение к организации $orgId успешно установлено." -ForegroundColor Cyan
        return
    }
    catch {
        Write-Error "Ошибка тестового подключения: $_"
        $global:Ya360Connected = $false
        throw
    }
}
