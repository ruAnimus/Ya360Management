function Remove-Ya360UserAlias {
    param (
            [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
            [Alias("ID")]
            $Ya360UserID,                               # Идентификатор пользователя
            [Parameter(Mandatory=$true)]
            [string]$alias                   # Набор контактов
        )
        
    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }
    
    $Ya360UserID = $Ya360UserID | Select-Object -First 1
    if ($Ya360UserID.ID) {
        $Ya360UserID = $Ya360UserID.ID
    }

    $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/users/$Ya360UserID/aliases/$alias"

    try {
        $Ya360Responce = Invoke-RestMethod -Uri $Uri `
            -Headers @{ 'Authorization' = $Ya360OAuthToken } `
            -Method Delete `
            -ContentType "application/json; charset=utf-8" `
            -TimeoutSec 120 `
            -ErrorAction Stop

        return $Ya360Responce
    }
    catch {
        Write-Error "Ошибка при изменении информации алиасов пользователя: $_"
        throw
    }
    return
}
