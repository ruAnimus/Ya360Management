function Get-Ya360User {
    [CmdletBinding(DefaultParameterSetName = 'ByID')]
    param (
        # ID пользователя.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="ByID",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="ID родительского департамента.")]
        [Alias("id")]
        [string]$Ya360UserID,

        # Nickname пользователя.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="ByNickname",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Nickname пользователя.")]
        [string]$Nickname,
        
        # Обновить кэш принудительно
        [Parameter(Position=1,
                   ParameterSetName="ByNickname",
                   HelpMessage="Обновить кэш польтзователей принудительно?")]
        [switch]$ForceRenewCache
    )

    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }

    if ($Nickname = $Nickname.Trim()) {
        Write-Verbose "Режим поиска пользователя по Nickname ($Nickname)"
        try {
            if ($ForceRenewCache) {
                Return Get-Ya360UserList -ForceRenewCache -ErrorAction Stop | Where-Object {$_.nickname -eq $Nickname}
            } else {
                if ( -not ($Ya360UserID = (Get-Ya360UserList -ReturnHashtable -ErrorAction Stop )[$Nickname].id)) {
                    Write-Error "Не удаётся найти объект с nickname ($Nickname) в организации $Ya360OrgID"
                    throw
                }
            }
        } catch {
            Write-Error "Не удаётся найти объект с nickname ($Nickname) в организации $Ya360OrgID : $_"
            throw
        }
    }
    
    # Write-Verbose "Запрос к api360.yandex.net по ID пользователя $Ya360UserID"
    try {
        $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/users/$Ya360UserID"
        Write-Verbose "Запрос: $Uri"
        
        $Ya360Responce = Invoke-WebRequest $Uri `
            -Headers @{ 'Authorization' = $Ya360OAuthToken } `
            -Method Get `
            -UseBasicParsing `
            -TimeoutSec 120 `
            -ErrorAction Stop

        if ($Ya360Responce.StatusCode -ne "200") {
            Write-Error "Invoke-WebRequest выполнен, но StatusCode не 200 : $($Ya360Responce.StatusCode)"
            throw
        }

        $Ya360ResponceInfo = $Ya360Responce.Content | ConvertFrom-Json
        # $Ya360ResponceInfo = $Ya360Responce | ConvertFrom-Json
        return $Ya360ResponceInfo
    }
    catch {
        Write-Error "Ошибка при запросе информации о пользователе: $_"
        throw
    }
}
