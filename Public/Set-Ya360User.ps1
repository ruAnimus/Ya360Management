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
