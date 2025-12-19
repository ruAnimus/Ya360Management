function Set-Ya360UserMailSenderInfo {
    param (
            [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
            [Alias("ID")]
            $Ya360UserID,                               # Замените на идентификатор пользователя
            [PSCustomObject]$SenderInfoParameters,
            [string]$DefaultFrom,                       # "новый_основной_адрес@ваш_домен"
            [string]$FromName,                          # "Имя Пользователя"
            [PSCustomObject]$Signs,
            [ValidateSet("bottom", "under")]
            [string]$SignPosition                       # расположение подписи
        )
        
        if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }
    
    $Ya360UserID = $Ya360UserID | Select-Object -First 1
    if ($Ya360UserID.ID) {
        $Ya360UserID = $Ya360UserID.ID
    }

    if ($SenderInfoParameters) {
        if ( ! (Test-Ya360UserMailSenderInfoParameters -Signature $SenderInfoParameters)) {
            Write-Error "Параметр SenderInfoParameters указан некорректно"
            throw
        }
    } else {
        
        try {
            $SenderInfoParameters = Get-Ya360UserMailSenderInfo -Ya360UserID $Ya360UserID -ErrorAction Stop
        } catch {
            Write-Error "Error Get-Ya360UserMailSenderInfo -Ya360UserID $Ya360UserID : $_"
            throw
        }
    }
    
    if ($DefaultFrom) {
        $SenderInfoParameters.defaultFrom = $DefaultFrom
    }
    if ($FromName) {
        $SenderInfoParameters.FromName = $FromName
    }
    if ($SignPosition) {
        $SenderInfoParameters.SignPosition = $SignPosition
    }
    if ($Signs) {
        # $SenderInfoParameters.Signs = @($Signs)
    }

    if ( ! ( Test-Ya360UserMailSenderInfoParameters -Signature $SenderInfoParameters )) {
        Write-Error "SenderInfoParametersSet is not valid : $($SenderInfoParameters | ConvertTo-Json -Depth 8 -Compress )"
        throw
    }

    <# пример структуры с параметрами
        $testSignature = [PSCustomObject]@{
        defaultFrom = "John Doe"
        fromName = "John"
        signPosition = "Manager"
        signs = @(
            [PSCustomObject]@{
                emails = @("john@example.com")
                isDefault = $true
                lang = "English"
                text = "This is my email signature."
            }
            )
        }
    #>
        
    $Uri = "https://api360.yandex.net/admin/v1/org/$Ya360OrgID/mail/users/$Ya360UserID/settings/sender_info"
    try {
        $Ya360Responce = Invoke-RestMethod -Uri $Uri `
        -Headers @{ 'Authorization' = $Ya360OAuthToken } `
        -Method Post `
        -ContentType "application/json; charset=utf-8" `
        -Body ($SenderInfoParameters | ConvertTo-Json -Depth 8 -Compress ) `
        -TimeoutSec 120 `
        -ErrorAction Stop

        if (( $SenderInfoParameters |ConvertTo-Json -Compress -Depth 4  ) -ne ( $( $Ya360Responce | ConvertTo-Json -Compress -Depth 4 ) -replace '&quot;','\"' ) ) {
            Write-Error "Invoke-RestMethod выполнен, но данные не применены (Send $($SenderInfoParameters |ConvertTo-Json -Compress -Depth 4 ); Responce $($Ya360Responce|ConvertTo-Json -Compress -Depth 4 ))"
            throw
        }
    }
    catch {
        Write-Error "Ошибка при изменении информации о адресе и подписи пользователя: $_"
        throw
    }
    return
}
