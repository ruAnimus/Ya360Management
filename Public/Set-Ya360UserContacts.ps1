function Set-Ya360UserContacts {
    param (
            [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
            [Alias("ID")]
            $Ya360UserID,                               # Идентификатор пользователя
            [PSCustomObject]$Contacts,                  # Набор контактов
            [string]$EmailContact                       # Добавить email как основной контакт
        )
        
    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }
    
    if (! ($Contacts) -and ! ($EmailContact)) {
        Write-Error "Не заданы необходимые параметры Contacts или EmailContact"
        throw
    }

    $Ya360UserID = $Ya360UserID | Select-Object -First 1
    if ($Ya360UserID.ID) {
        $Ya360UserID = $Ya360UserID.ID
    }

    $NewContact = @()

    if ($EmailContact) {
        $NewContact += @(New-Ya360ContactObject -label $EmailContact -type "email" -value $EmailContact)
    }

    if ($Contacts) {
        $NewContact += @($Contacts)
    }

    if ( ! (Test-Ya360ContactObject -Contact $NewContact)) {
        Write-Error "Set-Ya360UserContacts : Не удалось собрать массив с новыми контактами из переданных параметров ($($NewContact| ConvertTo-Json -Compress))"
        throw
    }
    
    # Должно быть
    # { "contacts": [ { "label": "string", "type": "string", "value": "string" } ]}
    $sendData = 1 | Select-Object contacts
    $sendData.contacts = @($NewContact)

    $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/users/$Ya360UserID/contacts"
    try {
        $Ya360Responce = Invoke-RestMethod -Uri $Uri `
            -Headers @{ 'Authorization' = $Ya360OAuthToken } `
            -Method Put `
            -ContentType "application/json; charset=utf-8" `
            -Body ($sendData | ConvertTo-Json -Depth 8 -Compress) `
            -TimeoutSec 120 `
            -ErrorAction Stop

        return $Ya360Responce
    }
    catch {
        Write-Error "Ошибка при изменении информации контактов пользователя: $_"
        throw
    }
    return
}
