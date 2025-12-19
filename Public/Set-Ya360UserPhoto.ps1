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
