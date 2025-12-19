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
