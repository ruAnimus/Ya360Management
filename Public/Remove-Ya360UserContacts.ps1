function Remove-Ya360UserContacts {
    param (
            [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
            [Alias("ID")]
            $Ya360UserID                                # Идентификатор пользователя

        )
        
    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }

    $Ya360UserID = $Ya360UserID | Select-Object -First 1
    if ($Ya360UserID.ID) {
        $Ya360UserID = $Ya360UserID.ID
    }

    $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/users/$Ya360UserID/contacts"
    try {
        $Ya360Responce = Invoke-RestMethod -Uri $Uri `
            -Headers @{ 'Authorization' = $Ya360OAuthToken } `
            -Method Delete `
            -ContentType "application/json; charset=utf-8" `
            -TimeoutSec 120 `
            -ErrorAction Stop

        $Ya360Responce.contacts | Format-Table
    }
    catch {
        Write-Error "Ошибка при изменении информации контактов пользователя: $_"
        throw
    }
    return
}
