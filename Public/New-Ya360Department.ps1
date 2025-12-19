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
