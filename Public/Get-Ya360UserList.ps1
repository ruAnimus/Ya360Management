function Get-Ya360UserList {
    param (
        # Обновить кэш списка пользователей
        [Parameter(Mandatory=$false,
                   Position=0,
                   HelpMessage="Обновить кэш списка пользователей.")]
        [switch]$ForceRenewCache,

        # Вернуть хэштейбл
        [Parameter(Mandatory=$false,
                   Position=1,
                   HelpMessage="Вернуть хештейбл Имя=Данные.")]
        [switch]$ReturnHashtable
    )

    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        return
    }

    # Обновить кэш?
    if (! $global:Ya360userListHashtable -or $ForceRenewCache -or ! $ReturnHashtable) {
        Write-Host "Обновление кэша для поиска по Nickname..."

        $Ya360RespPage = 1
        $Ya360RespPageTotal = 0
        $Ya360UserList = @()
        
        do {
            $AttemptNumber = 1
            while ($AttemptNumber -le 3) {
                $AttemptNumber++
                try {
                    $Ya360Responce = Invoke-WebRequest "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/users/?page=$Ya360RespPage&perPage=100" `
                        -Headers @{ 'Authorization' = $Ya360OAuthToken } `
                        -Method get `
                        -UseBasicParsing `
                        -TimeoutSec 120 `
                        -ErrorAction Stop
                    break
                }
                catch {
                    Write-Warning "Ошибка Invoke-WebRequest (страница $Ya360RespPage из $Ya360RespPageTotal ), при попытке № $AttemptNumber : $($_ -join " : ")"
                    Start-Sleep -Seconds 10
                }
            }
            if ( $AttemptNumber -gt 3 ) {
                Write-Error "Ошибка Invoke-WebRequest (страница $Ya360RespPage из $Ya360RespPageTotal ) : $($_ -join " : ")"
                throw
            }
                
            if ($Ya360Responce.StatusCode -ne "200") {
                Write-Error "Invoke-WebRequest выполнен, но StatusCode не 200 (страница $Ya360RespPage из $Ya360RespPageTotal ) : $($Ya360Responce.StatusCode)"
                throw
            }
            
            $Ya360ResponceInfo = $Ya360Responce.Content | ConvertFrom-Json
            $Ya360UserList += $Ya360ResponceInfo.users
            $Ya360RespPageTotal = $Ya360ResponceInfo.pages
            
            Write-Progress -Activity "Получение пользователей от api360.yandex.net" -Status ("Cтраница $Ya360RespPage из $($Ya360RespPageTotal), пользователей выгружено $(($Ya360UserList).Count) из $($Ya360ResponceInfo.total)") -PercentComplete (($Ya360RespPage) * 100 / $($Ya360ResponceInfo.pages))
            # Write-Host ("Получение от api360.yandex.net данных, страница $Ya360RespPage, пользователей " + ($Ya360UserList).Count)
            $Ya360RespPage++
    
        } while ( $Ya360RespPage -le $Ya360ResponceInfo.pages )

        try {
            $global:Ya360userListHashtable = @{}
            foreach ($cur in $($Ya360UserList ).psobject.BaseObject) {
                # $global:Ya360userListHashtable[$cur.nickname] = $cur.ID
                $global:Ya360userListHashtable[$cur.nickname] =
                    [PSCustomObject]@{
                        id = [UInt64]$cur.id
                        departmentId = [UInt64]$cur.departmentId
                    }
            }

        }
        catch {
            Write-Warning "Ошибка хэширования пользователей : $_"
            $global:Ya360userListHashtable = @{}
            throw
        }
    }

    if ($ReturnHashtable) {
        return $global:Ya360userListHashtable
    } else {
        return $Ya360UserList
    }
}
