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
