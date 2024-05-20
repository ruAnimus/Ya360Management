
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


# Получение всех пользователей с яндексов
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

# Получение пользователя с яндексов по YaID
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

# Просмотреть правила автоответа и пересылки
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

# Просмотреть статус автоматического сбора контактов
function Get-Ya360UserMailAddressBook {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [Alias("ID")]
        $Ya360UserID
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
        $Uri = "https://api360.yandex.net/admin/v1/org/$Ya360OrgID/mail/users/$Ya360UserID/settings/address_book"
        
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
        Write-Error "Ошибка при запросе информации о статусе автоматического сбора контактов: $_"
        throw
    }
}

# Реализация функции Просмотреть основной адрес и подписи (https://yandex.ru/dev/api360/doc/ref/MailUserSettingsService/MailUserSettingsService_GetSenderInfo.html)
function Get-Ya360UserMailSenderInfo {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [Alias("ID")]
        $Ya360UserID
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
        $Uri = "https://api360.yandex.net/admin/v1/org/$Ya360OrgID/mail/users/$Ya360UserID/settings/sender_info"
        
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
        Write-Error "Ошибка при запросе sender_info: $_"
        throw
    }
}
# Изменить основной адрес и подписи
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

# проверка структуры параметров для командлета Set-Ya360UserMailSenderInfo
function Test-Ya360UserMailSenderInfoParameters {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [PSCustomObject]$Signature
        )

    if ($Signature.PSObject.Properties.Name -eq "defaultFrom" -and
        $Signature.PSObject.Properties.Name -eq "fromName" -and
        $Signature.PSObject.Properties.Name -eq "signPosition" -and
        $Signature.PSObject.Properties.Name -eq "signs") {
            
            # Проверка типов свойств
            if ( ! ($Signature.defaultFrom -is [string] -and
                $Signature.fromName -is [string] -and
                $Signature.signPosition -is [string] -and
                $Signature.signs -is [array])) {
                # return $true
                Write-Error "Ошибка: Структура не соответствует ожидаемым типам данных."
                return $false
            }
        # Проверка свойства "signs"
        if ($Signature.signs -is [array] ) {
            foreach ($sign in $Signature.signs) {
                if ($sign.PSObject.Properties.Name -eq "emails" -and
                    $sign.PSObject.Properties.Name -eq "isDefault" -and
                    $sign.PSObject.Properties.Name -eq "lang" -and
                    $sign.PSObject.Properties.Name -eq "text") {

                        <# if ( -not (
                            $sign.emails -is [array] -and
                            $sign.emails.ForEach{ $_ -is [string] } -and
                            $sign.isDefault -is [boolean] -and
                            $sign.lang -is [string] -and
                            $sign.text -is [string]
                            ) ) {
                                Write-Error "Ошибка: Внутренняя структура 'signs' не соответствует ожидаемым типам данных."
                                return $false
                        } #>

                    continue
                } else {
                    Write-Error "Ошибка: Свойства внутренней структуры 'signs' не соответствуют ожидаемой структуре."
                    return $false
                }
            }
        } else {
            Write-Error "Ошибка: Свойство 'signs' должно быть массивом."
            return $false
        }
    } else {
        Write-Error "Ошибка: Структура не соответствует ожидаемой структуре."
        return $false
    }

    return $true
}

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
# Создание объекта Контакт https://yandex.ru/dev/api360/doc/ref/UserService/UserService_UpdateContacts.html
function New-Ya360ContactObject {
    param (
        [string]$label,
        [ValidateSet("email","phone_extension", "phone","site", "icq","twitter")]
        [string]$type = "email",
        [Parameter(Mandatory=$true)]
        [string]$value
    )

    $contact = [PSCustomObject]@{
        label = $label
        type = $type
        value = $value
    }
    return @($contact)
}
function Test-Ya360ContactObject {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        $Contact
    )

    $contact = @($contact)
    $requiredFields = @("type","value")
    foreach ($field in $requiredFields) {
        if (-not ($contact | Get-Member -Name $field)) {
            Write-Error "Обязательное поле $field отсутствует в объекте."
            return $false
        }
    }

    $validTypes = "email","phone_extension", "phone","site", "icq","twitter","staff"
    foreach ($cur in $contact ) {
        if (-not ($cur.type -in $validTypes)) {
            Write-Error "Недопустимое значение поля 'type'."
            return $false
        }
        if (-not $cur.value) {
            Write-Error "Пустое значение контакта недопустимо $($contact | ConvertTo-Json -Compress)"
            return $false
        }
    }

    return $true

}

# Изменить информацию
# https://yandex.ru/dev/api360/doc/ref/UserService/UserService_Update.html
function Set-Ya360User {
    [CmdletBinding(DefaultParameterSetName = 'ByUserObject',SupportsShouldProcess=$true)]
    param (
            # ID пользователя.
            [Parameter(Mandatory=$true,
                    Position=0,
                    ParameterSetName="ByID",
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    HelpMessage="ID пользователя.")]
            [Alias("id")]
            [UInt64]$Ya360UserID,  

            # Объект Ya360 пользователь
            [Parameter(Mandatory=$true,
                Position=0,
                ParameterSetName="ByUserObject",
                ValueFromPipeline=$true,
                HelpMessage="Обхект пользователя, содержащий все параметры")]
            [PSCustomObject]$user,

            [string]$about,
            [string]$birthday,
            [string]$contactType,
            [string]$contactValue,
            [string]$contactlabel,
            [int]$departmentId,
            [string]$externalId,
            [string]$gender,
            [bool]$isAdmin,
            [bool]$isEnabled,
            [string]$language,
            [string]$firstName,
            [string]$lastName,
            [string]$middleName,
            [string]$password,
            [bool]$passwordChangeRequired,
            [string]$position,
            [string]$timezone
        )
        
    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }


    if ($user) {
        Write-Verbose "Режим редактирования параметров пользователя: $($user.id)"
        $UserSet = $user
        if ( ! ( $Ya360UserID = $user.id)) {
            Write-Error "Редактируемый объект пользователя не содержит ID."
            throw
        }
        if ($contactValue) {
            if (-not $contactType ) {$contactType = "email"}
            try {
                $contact = @( New-Ya360ContactObject -value $contactValue -label $contactlabel -type $contactType -ErrorAction Stop)
                $UserSet.contact += $contact
            }
            catch {
                Write-Error "New-Ya360ContactObject -value $contactValue -label $contactlabel -type $contactType : $_"
                throw
            }
        }
        if ($firstName) { $UserSet.name.first = $firstName }
        if ($lastName) { $UserSet.name.last = $lastName }
        if ($middleName) { $UserSet.name.middle = $middleName }
        if ($about) { $UserSet.about = $about }
        if ($birthday) { $UserSet.birthday = $birthday }
        if ($departmentId) { $UserSet.departmentId = $departmentId }
        if ($externalId) { $UserSet.externalId = $externalId }
        if ($gender) { $UserSet.gender = $gender }
        if ($isAdmin) { $UserSet.isAdmin = $isAdmin }
        if ($isEnabled) { $UserSet.isEnabled = $isEnabled }
        if ($language) { $UserSet.language = $language }
        if ($password) { $UserSet.password = $password }
        if ($passwordChangeRequired) { $UserSet.passwordChangeRequired = $passwordChangeRequired }
        if ($position) { $useUserSetr.position = $position }
        if ($timezone) { $UserSet.timezone = $timezone }


    } else {
        Write-Verbose "Режим подготовки параметров пользователя $Ya360UserID"
        try {
            $UserSet = New-Ya360UserObject -about $about `
                -birthday $birthday `
                -contactType $contactType `
                -contactValue $contactType `
                -contactlabel $contactlabel `
                -departmentId $departmentId `
                -externalId $externalId `
                -gender $gender `
                -isAdmin $isAdmin `
                -isEnabled $isEnabled `
                -language $language `
                -firstName $firstName `
                -lastName $lastName `
                -middleName $middleName `
                -password $password `
                -passwordChangeRequired $passwordChangeRequired `
                -position $position `
                -timezone $timezone `
                -ErrorAction Stop
        }
        catch {
            Write-Error "New-Ya360UserObject : $_"
            throw
        }
    }

    Write-Verbose "Целевой пользователь: $Ya360UserID, данные для изменения: $UserSet"
    if ( ! (Test-Ya360UserObject -user $UserSet)) {
        Write-Error "Test-Ya360UserObject : сформированные параметры не прошли проверку ($($UserSet| ConvertTo-Json -Compress))"
        throw
    }
    
    $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/users/$Ya360UserID"
    if($PSCmdlet.ShouldProcess($Ya360UserID,"Invoke-RestMethod -Method Patch")) {
        try {
            $Ya360Responce = Invoke-RestMethod -Uri $Uri `
                -Headers @{ 'Authorization' = $Ya360OAuthToken } `
                -Method Patch `
                -ContentType "application/json; charset=utf-8" `
                -Body ($UserSet | ConvertTo-Json -Depth 4 -Compress) `
                -TimeoutSec 120 `
                -ErrorAction Stop
                
            $global:Ya360userListHashtable[$Ya360Responce.nickname].departmentId = [UInt64]$Ya360Responce.departmentId
            return $Ya360Responce
        }
        catch {
            Write-Error "Ошибка при изменении информации контактов пользователя: $_"
            throw
        }
            
    }

    return
}
# Создание PSCustomObject Пользователь
function New-Ya360UserObject {
    param (
        [string]$about,
        [string]$birthday,
        [string]$contactType,
        [string]$contactValue,
        [string]$contactlabel,
        [int]$departmentId,
        [string]$externalId,
        [string]$gender,
        [bool]$isAdmin,
        [bool]$isEnabled,
        [string]$language,
        [string]$firstName,
        [string]$lastName,
        [string]$middleName,
        [string]$password,
        [bool]$passwordChangeRequired,
        [string]$position,
        [string]$timezone
    )

    $user = @{}

    if ($firstName -or $lastName -or $middleName ) {
        $name = @{}
        if ($firstName) { $name.first = $firstName }
        if ($lastName) { $name.last = $lastName }
        if ($middleName) {$name.middle = $middleName}
    
        $user.name = [PSCustomObject]$name
    }

    
    if ($contactValue) {
        if (-not $contactType ) {$contactType = "email"}
        $contacts = @( New-Ya360ContactObject -value $contactValue -label $contactlabel -type $contactType )
        $user.contacts = $contacts
    }
    
    if ($about) { $user.about = $about }
    if ($birthday) { $user.birthday = $birthday }
    if ($departmentId) { $user.departmentId = $departmentId }
    if ($externalId) { $user.externalId = $externalId }
    if ($gender) { $user.gender = $gender }
    if ($isAdmin) { $user.isAdmin = $isAdmin }
    if ($isEnabled) { $user.isEnabled = $isEnabled }
    if ($language) { $user.language = $language }
    if ($password) { $user.password = $password }
    if ($passwordChangeRequired) { $user.passwordChangeRequired = $passwordChangeRequired }
    if ($position) { $user.position = $position }
    if ($timezone) { $user.timezone = $timezone }
    
    return [PSCustomObject]$user
}
function Test-Ya360UserObject {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]    
        [PSCustomObject]$user
    )

    if ($user -isnot [PSCustomObject]) {
        Write-Host "Входной объект не является PSCustomObject."
        return $false
    }

    # Проверка наличия и непустоту обязательных полей
    # if (-not ($user.name -is [PSCustomObject]) -or -not $user.name.first -or -not $user.name.last) {
    #     Write-Host "Поля 'name.first' и 'name.last' обязательны."
    #     return $false
    # }

    $rep = @()
    # Проверка наличия остальных полей
    $requiredFields = @("about", "birthday", "contacts", "departmentId",
        "externalId", "gender", "isAdmin", "isEnabled", "language",
        "password", "passwordChangeRequired", "position", "timezone",
        "id", "nickname", "email", "name", "avatarId", "aliases",
        "groups", "isRobot", "isDismissed", "createdAt", "updatedAt",
        "IsSynchronized", "SyncRoot", "Count"
    )
    foreach ($field in $user.PSObject.Properties.name) {
        if (-not ($field -in $requiredFields)) {
            $rep += $field
        }
    }
    if ($rep) {
        Write-Warning "В объекте присутствуют незадокументированные поля [$($rep -join ", ")]"
    }
    
    if ($user.contacts) {
        Write-Verbose ($user.contacts | ConvertTo-Json )
        if (-not (Test-Ya360ContactObject -Contact $($user.contacts))) {
            Write-Host "В объекте присутствуют поле contacts, но содержит некорректные данные ($($user.contacts | ConvertTo-Json -Compress))"
            return $false
        }
    }

    return $true

}

# Добавляет сотруднику алиас почтового ящика.
function Add-Ya360UserAlias {
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

    $sendData = 1 | Select-Object alias
    $sendData.alias = $alias

    $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/users/$Ya360UserID/aliases"
    try {
        $Ya360Responce = Invoke-RestMethod -Uri $Uri `
            -Headers @{ 'Authorization' = $Ya360OAuthToken } `
            -Method Post `
            -ContentType "application/json; charset=utf-8" `
            -Body ($sendData | ConvertTo-Json -Compress) `
            -TimeoutSec 120 `
            -ErrorAction Stop

        return $Ya360Responce
    }
    catch {
        Write-Error "Ошибка при изменении информации алиасов пользователя: $($_ -join ", " )"
        throw
    }
    return
}
# Удаляет у сотрудника алиас почтового ящика
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

function Set-Ya360UserPhoto {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory=$True)]    
        [Alias("ID")]
        $Ya360UserID,
        [Parameter(Mandatory=$True)]
        [Alias("Path")]
        [string]$PhotoPath
    )

    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }

    $Ya360UserID = $Ya360UserID | Select-Object -First 1
    if ($Ya360UserID.ID) {
        $Ya360UserID = $Ya360UserID.ID
    }

    if ( ! (Test-Path $PhotoPath )) {
        Write-Error "File not found '$PhotoPath'"
        throw
    }
    # $PhotoPath = Join-Path ( $env:temp) "adphoto.jpg"

    # try {
    #     $userAD.thumbnailPhoto | Set-Content $PhotoPath -AsByteStream -Force -Confirm:$false -ErrorAction Stop
    # }
    # catch {
    #     Write-Error "Set-Content $PhotoPath : $_"
    #     throw
    # }

    # Может получится без сохранения на диск?
    # $base64Image = [convert]::ToBase64String((get-content $path -encoding byte))

    try {
        $Ya360Resp = Invoke-RestMethod -Method 'Put' `
            -Uri "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/users/$Ya360UserID/avatar" `
            -Infile $PhotoPath `
            -ContentType "image/jpg" `
            -Headers @{ 'Authorization' = $Ya360OAuthToken } `
            -TimeoutSec 120 `
            -ErrorAction Stop
    }
    catch {
        Write-Error "Invoke-RestMethod не выполнен : $_"
        throw
    }
    return $Ya360Resp
}


# Реализация функции Получить аудит лог Диска (https://yandex.ru/dev/api360/doc/ref/AuditLogService/AuditLogService_Disk.html)
function Get-Ya360AuditLogDisk {
    param (
        # Количество событий на странице. Максимальное значение — 100.
            [Parameter(
                Position=0,
                HelpMessage="Количество событий на странице. Максимальное значение — 100.")
            ]
            [ValidateNotNullOrEmpty()]
            [Int64]
        $PageSize = 10,

        # Токен постраничной навигации.
            [Parameter(
                HelpMessage="Токен постраничной навигации.")
            ]
            [ValidateNotNullOrEmpty()]
            [string]
        $PageToken,

        # Верхняя граница периода выборки в формате ISO 8601, например 2022-12-31T23:59:59+03:00 или 2022-12-31T12:00:00Z. Значение по умолчанию — текущее время.
            [Parameter(
                HelpMessage="Верхняя граница периода выборки в формате ISO 8601, например 2022-12-31T23:59:59+03:00 или 2022-12-31T12:00:00Z. Значение по умолчанию — текущее время.")
            ]
            [ValidateNotNullOrEmpty()]
            [string]
        $BeforeDate,

        # Нижняя граница периода выборки в формате ISO 8601, например 2022-12-31T23:59:59+03:00 или 2022-12-31T12:00:00Z.
            [Parameter(
                HelpMessage="Нижняя граница периода выборки в формате ISO 8601, например 2022-12-31T23:59:59+03:00 или 2022-12-31T12:00:00Z.")
            ]
            [ValidateNotNullOrEmpty()]
            [string]
        $AfterDate,

        # Список пользователей, действия которых должны быть включены в список событий.
            [Parameter(
                HelpMessage="Список пользователей, действия которых должны быть включены в список событий.")
            ]
            [ValidateNotNullOrEmpty()]
            [string[]]
        $IncludeUids,

        # Список пользователей, действия которых должны быть исключены из списка событий.
            [Parameter(
                HelpMessage="Список пользователей, действия которых должны быть исключены из списка событий.")
            ]
            [ValidateNotNullOrEmpty()]
            [string[]]
        $ExcludeUids
    )

    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        return
    }
    
    <# Примеры параметров
        $pageToken = "yourPageToken",
        $beforeDate = "2023-01-01T00:00:00Z",
        $afterDate = "2023-01-01T00:00:00Z",
        $includeUids = @("uid1", "uid2"),
        $excludeUids = @("uid3", "uid4")
    #>

    $uri = "https://api360.yandex.net/security/v1/org/$Ya360OrgID/audit_log/disk"
        # "?pageSize=$pageSize"
        # "&pageToken=$pageToken" +
        # "&beforeDate=$beforeDate" +
        # "&afterDate=$afterDate" +
        # "&includeUids=$includeUids" +
        # "&excludeUids=$excludeUids"

    try {
        if ($pageSize -gt 100 ) {$pageSize = 100}
            $uri += "?pageSize=$pageSize"
        if ($pageToken) {
            $uri += "&pageToken=$pageToken"
        }
        if ($beforeDate) {
            $beforeDate = Get-Date $beforeDate -UFormat '+%Y-%m-%dT%H:%M:%S.00Z' -ErrorAction Stop
            $uri += "&beforeDate=$beforeDate"
        }
        if ($afterDate) {
            $afterDate = Get-Date $afterDate -UFormat '+%Y-%m-%dT%H:%M:%S.00Z' -ErrorAction Stop
            $uri += "&afterDate=$afterDate"
        }
        if ($includeUids) {
            $includeUids = $($includeUids -join ',')
            $uri += "&includeUids=$includeUids"
        }
        if ($excludeUids) {
            $excludeUids = $($excludeUids -join ',')
            $uri += "&excludeUids=$excludeUids"
        }
    }
    catch {
        Write-Error "Параметры не корректны: $_"
        throw
    }


    try {

        $Ya360Responce = Invoke-WebRequest -Uri $uri `
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
        Write-Error "Ошибка при запросе Invoke-WebRequest: $_"
        throw
    }
}


# Реализация функции Посмотреть список подразделений (https://yandex.ru/dev/api360/doc/ref/DepartmentService/DepartmentService_List.html)
function Get-Ya360DepartmentList {
    [CmdletBinding(DefaultParameterSetName = 'DepAll')]
    param (
        # ID родительского департамента.
        [Parameter(Mandatory=$false,
                   Position=0,
                   ParameterSetName="DepByParentId",
                   ValueFromPipeline=$true,
                   HelpMessage="ID родительского департамента.")]
        [ValidateNotNullOrEmpty()]
        [Alias("id")]
        [UInt64]$parentId,

        # Работать только в онлайн, без использования кэша (но обновить при случае)
        [Parameter(Mandatory=$false,
                   Position=1,
                   ParameterSetName="DepByParentId",
                   ValueFromPipeline=$true,
                   HelpMessage="Получать подразделения онлайн, без использования кэша.")]
        [Parameter(Mandatory=$false,
                   Position=0,
                   ParameterSetName="DepAll",
                   HelpMessage="Обновить кэш списка подразделений.")]
        [ValidateNotNullOrEmpty()]
        [switch]$OnlineOnly,
        
        # Рекурсивный поиск подотделов.
        [Parameter(Mandatory=$false,
                   Position=2,
                   ParameterSetName="DepByParentId",
                   HelpMessage="Рекурсивный поиск подотделов.")]
        [ValidateNotNullOrEmpty()]
        [switch]$Recursive
    )

    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }

    # Нужно ли в онлайн?
    if ( ! $global:Ya360DepartmentsCache -or $OnlineOnly )  {
        
        Write-Host "Download department list..."
        
        $Ya360RespPage = 0
        $Ya360RespPageTotal = 0
        $Ya360DepartReceived = @()

        # Добавить в строку запроса parentID
        if ( $parentId -and $OnlineOnly ) { $uriParentId = "&parentId=$parentId" } else { $uriParentId = "" }
        do {
            $Ya360RespPage++
            $uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/departments/?page=$Ya360RespPage$uriParentId"
            # if ($parentId) { $uri += "&parentId=$parentId" }
            
            try {
                $Ya360Responce = Invoke-WebRequest $Uri `
                -Headers @{ 'Authorization' = $Ya360OAuthToken } `
                -Method get `
                -UseBasicParsing `
                -TimeoutSec 120 `
                -ErrorAction Stop
            }
            catch {
                Write-Error "Ошибка Invoke-WebRequest (страница $Ya360RespPage из $Ya360RespPageTotal ) : $($_ -join " : ")"
                throw
            }
    
            if ($Ya360Responce.StatusCode -ne "200") {
                Write-Error "Invoke-WebRequest выполнен, но StatusCode не 200 (страница $Ya360RespPage из $Ya360RespPageTotal ) : $($Ya360Responce.StatusCode)"
                throw
            }
            
            $Ya360ResponceInfo = $Ya360Responce.Content | ConvertFrom-Json
            $Ya360DepartReceived += $Ya360ResponceInfo.departments
            $Ya360RespPageTotal = $Ya360ResponceInfo.pages
            
            Write-Progress -Activity "Получение подразделений от api360.yandex.net" -Status ("Cтраница $Ya360RespPage из $($Ya360RespPageTotal), подразделений выгружено $(($Ya360DepartReceived).Count) из $($Ya360ResponceInfo.total)") -PercentComplete (($Ya360RespPage) * 100 / $($Ya360ResponceInfo.pages))
    
        } while ($Ya360RespPage -lt $Ya360ResponceInfo.pages)

        if ( $parentId -and $OnlineOnly ) {
            if ($Recursive) {
                $ChildDepartments = @()
                foreach ($cur in $Ya360DepartReceived) {
                    try {
                        $ChildDepartments += Get-Ya360DepartmentList -parentId $($cur.id) -Recursive -OnlineOnly -ErrorAction Stop
                    }
                    catch {
                        Write-Error "Get-Ya360DepartmentList -parentId $($cur.id) : $_"
                        throw
                    }
                }
                $Ya360DepartReceived += $ChildDepartments
            }
            
            # return $Ya360DepartReceived
            $Ya360DepartReceivedSetType = @()
            foreach ($cur in $Ya360DepartReceived) {
                $cur.id = [UInt64]$cur.id
                $cur.parentId = [UInt64]$cur.parentId

                $Ya360DepartReceivedSetType += $cur
            }
            return $Ya360DepartReceivedSetType
            $Ya360DepartReceived = $Ya360DepartReceivedSetType
            # Remove-Variable Ya360DepartReceivedSetType
        }
        
        # $global:Ya360DepartmentsCache = $Ya360DepartReceived

        try {
            $global:Ya360DepartmentsCache = @{}
            foreach ( $cur in $( $Ya360DepartReceived ).psobject.BaseObject ) {
                $cur.id = [UInt64]$cur.id
                $cur.parentId = [UInt64]$cur.parentId
                $global:Ya360DepartmentsCache[[UInt64]$cur.id] = $cur
            }
        }
        catch {
            Write-Warning "Ошибка хэширования подразделений : $_"
            $global:Ya360DepartmentsCache = @{}
            throw
        }

    }
    # Тут имеем актуальный обновлённый кэш всех подразделений
    
    if  (! $parentId) {
        return $global:Ya360DepartmentsCache.values
    }

    $return = @($global:Ya360DepartmentsCache.values | Where-Object {$_.parentId -eq $parentId})
    if ($Recursive) {
        $ChildDepartments = @()
        foreach ( $cur in $return ) {
            try {
                $ChildDepartments += Get-Ya360DepartmentList -parentId $($cur.id) -Recursive -ErrorAction Stop
            }
            catch {
                Write-Error "Get-Ya360DepartmentList -parentId $($cur.id) : $_"
                throw
            }
        }
        $return += $ChildDepartments
    }
    
    return $return
}

# Реализация функции Посмотреть информацию о подразделении (https://yandex.ru/dev/api360/doc/ref/DepartmentService/DepartmentService_Get.html)
function Get-Ya360Department {
    [CmdletBinding(DefaultParameterSetName = 'DepByID')]
    param (
        # Идентификатор подразделения.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="DepByID",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Идентификатор подразделения.")]
        [Alias("Ya360DepartmentId","ID")]
        [ValidateNotNullOrEmpty()]
        [UInt64]$DepartmentId
    )

    if (! $global:Ya360Connected) {
            Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        return
    }

    
    try {
        $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/departments/$DepartmentId"
        
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
        Write-Error "Ошибка при запросе информации об отделе: $_"
        throw
    }
}

# Реализация функции Изменить параметры подразделения (https://yandex.ru/dev/api360/doc/ref/DepartmentService/DepartmentService_Update.html)
function Set-Ya360Department {
    [CmdletBinding(DefaultParameterSetName = 'DepByID', SupportsShouldProcess=$true)]
    param (
        # Идентификатор подразделения.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="DepByID",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Идентификатор подразделения.")]
        [Alias("Ya360DepartmentId","ID")]
        [ValidateNotNullOrEmpty()]
        [UInt64]$DepartmentId,


        # Описание подразделения.
        [Parameter(Mandatory=$false,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    HelpMessage="Описание подразделения.")]
        [string]$Description,

        # Произвольный внешний идентификатор подразделения.
        [Parameter(Mandatory=$false,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    HelpMessage="Произвольный внешний идентификатор подразделения.")]
        [string]$ExternalId,

        # Идентификатор сотрудника-руководителя подразделения. 0 что бы удалить руководителя.
        [Parameter(Mandatory=$false,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    HelpMessage="Идентификатор сотрудника-руководителя подразделения. 0 что бы удалить руководителя.")]
        # [ValidateNotNull()]
        [string]$HeadId,

        # Имя почтовой рассылки подразделения. Например, для адреса new-department@ваш-домен.ru имя почтовой рассылки — это new-department..
        [Parameter(Mandatory=$false,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    HelpMessage="Имя почтовой рассылки подразделения. Например, для адреса new-department@ваш-домен.ru имя почтовой рассылки — это new-department..")]
        # [ValidateNotNull()]
        [string]$Label,

        # Новое название подразделения.
        [Parameter(Mandatory=$false,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,    
                    HelpMessage="Новое название подразделения.")]
        # [ValidateNotNull()]
        [string]$NameNew,

        # Идентификатор родительского подразделения.
        [Parameter(Mandatory=$false,
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true,
                    HelpMessage="Идентификатор родительского подразделения.")]
        # [ValidateNotNull()]
        [UInt64]$ParentId,

        # Идентификатор родительского подразделения.
        [Parameter(Mandatory=$false,
            HelpMessage="Очистить остальные поля, не указанные для изменения. В противном случае их значение остаётся прежним.")]
        [switch]$ClearOtherFields
    )

    if (! $global:Ya360Connected) {
            Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        return
    }

    if ($ClearOtherFields) {
        $RequestBodyJson = '{
            "description": "",
            "externalId": "",
            "headId": "0",
            "label": "",
            "name": "",
            "parentId": 1
        }'
        $RequestBody = $RequestBodyJson | ConvertFrom-Json
    } else {
        try {
            $RequestBody = Get-Ya360Department -departmentId $DepartmentId -ErrorAction Stop
        } catch {
            Write-Error "Error Get-Ya360UserMailSenderInfo -Ya360UserID $Ya360UserID : $_"
            throw
        }

    }

    if ( $Description = $Description.Trim() ) { $RequestBody.description = $Description }
    if ( $ExternalId = $ExternalId.Trim() ) { $RequestBody.externalId = $ExternalId }
    if ( $HeadId = $HeadId.Trim() ) { $RequestBody.HeadId = $HeadId }
    if ( $Label = $Label.Trim() ) { $RequestBody.Label = $Label }
    if ( $NameNew = $NameNew.trim() ) { $RequestBody.name = $NameNew }
    if ( $ParentId -gt 0 ) { $RequestBody.parentId = $ParentId } else {$RequestBody.parentId = 1}

    <# Пример структуры департмента
    {
        "id": 1,
        "name": "DepartmentName",
        "parentId": 0,
        "description": "",
        "externalId": "",
        "label": "",
        "email": "",
        "headId": "0",
        "membersCount": 11111,
        "aliases": [],
        "createdAt": "2018-11-11T05:43:04.097Z"
    } #>
    Write-Verbose $($RequestBody | ConvertTo-Json -Depth 8)
    if($PSCmdlet.ShouldProcess($DepartmentId,"Invoke-RestMethod -Method Patch")) {
        try {
            $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/departments/$DepartmentId"
            
            $Ya360Responce = Invoke-RestMethod -Uri $Uri `
                -Headers @{ 'Authorization' = $Ya360OAuthToken } `
                -Method Patch `
                -ContentType "application/json; charset=utf-8" `
                -Body ($RequestBody | ConvertTo-Json -Depth 8 -Compress ) `
                -TimeoutSec 120 `
                -ErrorAction Stop
    
            <# if ($Ya360Responce.StatusCode -ne "200") {
                Write-Error "Invoke-WebRequest выполнен, но StatusCode не 200 : $($Ya360Responce.StatusCode)"
                throw
            } #>
    
            # $Ya360ResponceInfo = $Ya360Responce.Content | ConvertFrom-Json
            $Ya360ResponceInfo = $Ya360Responce
            return $Ya360ResponceInfo
        }
        catch {
            Write-Error "Invoke-RestMethod: $_"
            throw
        }
    }
}

# Реализация функции Создать подразделение (https://yandex.ru/dev/api360/doc/ref/DepartmentService/DepartmentService_Create.html)
function New-Ya360Department {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (

        # Описание подразделения.
        [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true,
                HelpMessage="Описание подразделения.")]
        # [ValidateNotNullOrEmpty()]
        [string]$Description,

        # Произвольный внешний идентификатор подразделения.
        [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true,
                HelpMessage="Произвольный внешний идентификатор подразделения.")]
        # [ValidateNotNullOrEmpty()]
        [string]$ExternalId,

        # Идентификатор сотрудника-руководителя отдела.
        [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true,
                HelpMessage="Идентификатор сотрудника-руководителя отдела.")]
        [string]$HeadId,

        # Имя почтовой рассылки подразделения. Например, для адреса new-department@ваш-домен.ru имя почтовой рассылки — это new-department..
        [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true,
                HelpMessage="Имя почтовой рассылки подразделения. Например, для адреса new-department@ваш-домен.ru имя почтовой рассылки — это new-department..")]
        # [ValidateNotNullOrEmpty()]
        [string]$Label,

        # Новое название подразделения.
        [Parameter(Mandatory=$true,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true,
                HelpMessage="Новое название подразделения.")]
        # [ValidateNotNullOrEmpty()]
        [string]$Name,

        # Идентификатор родительского подразделения.
        [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true,
                HelpMessage="Идентификатор родительского подразделения.")]
        # [ValidateNotNullOrEmpty()]
        [UInt64]$ParentId

    )

    if (! $global:Ya360Connected) {
            Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        return
    }

    <# Пример структуры запроса
    '{
        "description": "",
        "externalId": "",
        "headId": "0",
        "label": "",
        "name": "",
        "parentId": 1
    }' #>

    $RequestBody = [ordered]@{ 
        name = $Name.trim()
        parentId = 1
        headId = 0
    }

    if ( $Description = $Description.Trim() ) { $RequestBody.description = $Description }
    if ( $ExternalId = $ExternalId.Trim() ) { $RequestBody.externalId = $ExternalId }
    if ( $HeadId = $HeadId.Trim() ) { $RequestBody.HeadId = $HeadId }
    if ( $Label = $Label.Trim() ) { $RequestBody.Label = $Label }
    # if ( $Name = $Name.trim() ) { $RequestBody.name = $Name }
    if ( $ParentId -gt 1 ) { $RequestBody.parentId = $ParentId }

    Write-Verbose  $( $RequestBody | ConvertTo-Json )
    if($PSCmdlet.ShouldProcess($($RequestBody | ConvertTo-Json -Depth 2 -Compress),"Invoke-RestMethod -Method Post")) {

        try {
            $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/departments"
            
            $Ya360Responce = Invoke-RestMethod -Uri $Uri `
                -Headers @{ 'Authorization' = $Ya360OAuthToken } `
                -Method Post `
                -ContentType "application/json; charset=utf-8" `
                -Body ($RequestBody | ConvertTo-Json -Depth 8 -Compress ) `
                -TimeoutSec 120 `
                -ErrorAction Stop
    
            <# if ($Ya360Responce.StatusCode -ne "200") {
                Write-Error "Invoke-WebRequest выполнен, но StatusCode не 200 : $($Ya360Responce.StatusCode) : $($Ya360Responce | ConvertTo-Json -Compress)"
                throw
            } #>
    
            # $Ya360ResponceInfo = $Ya360Responce.Content | ConvertFrom-Json
            $Ya360ResponceInfo = $Ya360Responce
            $Ya360ResponceInfo.id = [UInt64]$Ya360ResponceInfo.id
        }
        catch {
            Write-Error "Invoke-RestMethod: $($_ -join " ")"
            throw
        }

        if ($global:Ya360DepartmentsCache) {
            $global:Ya360DepartmentsCache.Add( [UInt64]$Ya360ResponceInfo.id, $Ya360ResponceInfo )
            # $global:Ya360DepartmentsCache.Remove( [UInt64]$DepartmentId )
        }
        
        return $Ya360ResponceInfo
    }
}

# Реализация функции Удалить подразделение (https://yandex.ru/dev/api360/doc/ref/DepartmentService/DepartmentService_Delete.html)
function Remove-Ya360Department {
    [CmdletBinding(DefaultParameterSetName = 'DepByID', SupportsShouldProcess=$true)]
    param (
        # Идентификатор подразделения.
        [Parameter(Mandatory=$true,
                   Position=0,
                   ParameterSetName="DepByID",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Идентификатор подразделения.")]
        [Alias("Ya360DepartmentId","ID")]
        [ValidateNotNullOrEmpty()]
        [UInt64]$DepartmentId,

        [switch]$Recursive,

        # Поведение с дочерними объектами.
        [Parameter(Mandatory=$false,
                Position=2,
                HelpMessage="Удалять дочерние подразделения и переместить пользователей в родительское подразделение?")]
        [switch]$Force

    )

    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }

    if ($DepartmentId -le 1) {
        Write-Error "Удаляемое подразделение является корневым, и не может быть удалено ($DepartmentId)."
        throw
    }

    try {
        $Ya360DepartmentsCacheRecur = @(Get-Ya360DepartmentList -parentId $DepartmentId -Recursive -ErrorAction Stop )
        $Ya360DepartmentsCacheCur = @(Get-Ya360DepartmentList -parentId $DepartmentId -ErrorAction Stop )
        $DepartmentIdList = @($DepartmentId) + @($Ya360DepartmentsCacheRecur | Select-Object -ExpandProperty id )

        $DepartmentMembers = @()
        foreach ($cur in ( Get-Ya360UserList -ReturnHashtable -ErrorAction Stop ).values) {
            if ($cur.departmentId -in $DepartmentIdList) {
                $DepartmentMembers += $cur
            }
        }
    }
    catch {
        Write-Error "Не удалось получить информацию о членстве в подразделении дочерних подразделений : $_"
        throw
    }

    if ( $DepartmentMembers.count -gt 0 ) {
        if ( ! $Force ) { 
            Write-Error "Удаляемое подразделение (ID $DepartmentId) содержит пользователей ($($DepartmentMembers.count)), принудительное удаление с параметром -Force"
            throw
        }

        try {
            $DepartmentParentId = (Get-Ya360Department -DepartmentId $departmentId -ErrorAction Stop).parentId
        }
        catch {
            Write-Error "Не удалось получить ParentId удаляемого подразделения."
            throw
        }

        foreach ($Cur in $DepartmentMembers ) {
            try {
                Set-Ya360User -Ya360UserID $cur.id -departmentId $DepartmentParentId -ErrorAction Stop
            }
            catch {
                Write-Error "Не удалось перенести пользователя ID $($cur.id) из удаляемого подразделения ID $departmentId в родительское подразделение $DepartmentParentId"
                throw
            }
        }
    }

    try {
        foreach ($cur in $Ya360DepartmentsCacheCur ) {
            Remove-Ya360Department -DepartmentId $cur.id -ErrorAction Stop
        }     
    }
    catch {
        Write-Error "Не удалось удалить дочернее подразделение ID $($cur.id) из удаляемого подразделения ID $departmentId"
        throw
    }

    if($PSCmdlet.ShouldProcess($DepartmentId,"Invoke-RestMethod -Method Delete")) {
        try {
            $Uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/departments/$DepartmentId"
            
            $Ya360Responce = Invoke-RestMethod -Uri $Uri `
                -Headers @{ 'Authorization' = $Ya360OAuthToken } `
                -Method Delete `
                -TimeoutSec 120 `
                -ErrorAction Stop
    
            Write-Verbose "Invoke-RestMethod Responce - $($Ya360Responce | ConvertTo-Json -Compress)"
            <# if ($Ya360Responce.StatusCode -ne "200") {
                Write-Error "Invoke-WebRequest выполнен, но StatusCode не 200 : $($Ya360Responce.StatusCode) : $($Ya360Responce | ConvertTo-Json -Compress)"
                throw
            } #>
    
            # $Ya360ResponceInfo = $Ya360Responce.Content | ConvertFrom-Json
            $Ya360ResponceInfo = $Ya360Responce
        }
        catch {
            Write-Error "Invoke-RestMethod: $_"
            throw
        }
        
        if ($global:Ya360DepartmentsCache) {
            $global:Ya360DepartmentsCache.Remove( [UInt64]$DepartmentId )
        }
        
        return $Ya360ResponceInfo
    }
    
}

