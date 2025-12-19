function Get-Ya360UserMailRules {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [Alias("ID")]
        [string]$Ya360UserID
    )
        
    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        return
    }
    
    $Ya360UserID = $Ya360UserID | Select-Object -First 1
    if ($Ya360UserID.ID) {
        $Ya360UserID = $Ya360UserID.ID
    }

    try {
        $Uri = "https://api360.yandex.net/admin/v1/org/$Ya360OrgID/mail/users/$Ya360UserID/settings/user_rules"
        
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
        return $Ya360ResponceInfo
    }
    catch {
        Write-Error "Ошибка при запросе информации о правилах пользователя: $_"
        throw
    }
}
