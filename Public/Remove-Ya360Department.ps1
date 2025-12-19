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
