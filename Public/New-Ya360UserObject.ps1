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
