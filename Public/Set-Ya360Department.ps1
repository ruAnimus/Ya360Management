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
