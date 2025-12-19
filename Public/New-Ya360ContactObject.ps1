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
