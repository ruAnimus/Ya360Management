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
