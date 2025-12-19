function Get-Ya360DepartmentList {
    [CmdletBinding(DefaultParameterSetName = 'DepAll')]
    param (
        # ID родительского департамента.
        [Parameter(Mandatory=$false,
                   Position=0,
                   ParameterSetName="DepByParentId",
                   ValueFromPipeline=$true,
                   HelpMessage="ID родительского департамента.")]
        [ValidateNotNullOrEmpty()]
        [Alias("id")]
        [UInt64]$parentId,

        # Работать только в онлайн, без использования кэша (но обновить при случае)
        [Parameter(Mandatory=$false,
                   Position=1,
                   ParameterSetName="DepByParentId",
                   ValueFromPipeline=$true,
                   HelpMessage="Получать подразделения онлайн, без использования кэша.")]
        [Parameter(Mandatory=$false,
                   Position=0,
                   ParameterSetName="DepAll",
                   HelpMessage="Обновить кэш списка подразделений.")]
        [ValidateNotNullOrEmpty()]
        [switch]$OnlineOnly,
        
        # Рекурсивный поиск подотделов.
        [Parameter(Mandatory=$false,
                   Position=2,
                   ParameterSetName="DepByParentId",
                   HelpMessage="Рекурсивный поиск подотделов.")]
        [ValidateNotNullOrEmpty()]
        [switch]$Recursive
    )

    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        throw
    }

    # Нужно ли в онлайн?
    if ( ! $global:Ya360DepartmentsCache -or $OnlineOnly )  {
        
        Write-Host "Download department list..."
        
        $Ya360RespPage = 0
        $Ya360RespPageTotal = 0
        $Ya360DepartReceived = @()

        # Добавить в строку запроса parentID
        if ( $parentId -and $OnlineOnly ) { $uriParentId = "&parentId=$parentId" } else { $uriParentId = "" }
        do {
            $Ya360RespPage++
            $uri = "https://api360.yandex.net/directory/v1/org/$Ya360OrgID/departments/?page=$Ya360RespPage$uriParentId"
            # if ($parentId) { $uri += "&parentId=$parentId" }
            
            try {
                $Ya360Responce = Invoke-WebRequest $Uri `
                -Headers @{ 'Authorization' = $Ya360OAuthToken } `
                -Method get `
                -UseBasicParsing `
                -TimeoutSec 120 `
                -ErrorAction Stop
            }
            catch {
                Write-Error "Ошибка Invoke-WebRequest (страница $Ya360RespPage из $Ya360RespPageTotal ) : $($_ -join " : ")"
                throw
            }
    
            if ($Ya360Responce.StatusCode -ne "200") {
                Write-Error "Invoke-WebRequest выполнен, но StatusCode не 200 (страница $Ya360RespPage из $Ya360RespPageTotal ) : $($Ya360Responce.StatusCode)"
                throw
            }
            
            $Ya360ResponceInfo = $Ya360Responce.Content | ConvertFrom-Json
            $Ya360DepartReceived += $Ya360ResponceInfo.departments
            $Ya360RespPageTotal = $Ya360ResponceInfo.pages
            
            Write-Progress -Activity "Получение подразделений от api360.yandex.net" -Status ("Cтраница $Ya360RespPage из $($Ya360RespPageTotal), подразделений выгружено $(($Ya360DepartReceived).Count) из $($Ya360ResponceInfo.total)") -PercentComplete (($Ya360RespPage) * 100 / $($Ya360ResponceInfo.pages))
    
        } while ($Ya360RespPage -lt $Ya360ResponceInfo.pages)

        if ( $parentId -and $OnlineOnly ) {
            if ($Recursive) {
                $ChildDepartments = @()
                foreach ($cur in $Ya360DepartReceived) {
                    try {
                        $ChildDepartments += Get-Ya360DepartmentList -parentId $($cur.id) -Recursive -OnlineOnly -ErrorAction Stop
                    }
                    catch {
                        Write-Error "Get-Ya360DepartmentList -parentId $($cur.id) : $_"
                        throw
                    }
                }
                $Ya360DepartReceived += $ChildDepartments
            }
            
            # return $Ya360DepartReceived
            $Ya360DepartReceivedSetType = @()
            foreach ($cur in $Ya360DepartReceived) {
                $cur.id = [UInt64]$cur.id
                $cur.parentId = [UInt64]$cur.parentId

                $Ya360DepartReceivedSetType += $cur
            }
            return $Ya360DepartReceivedSetType
            $Ya360DepartReceived = $Ya360DepartReceivedSetType
            # Remove-Variable Ya360DepartReceivedSetType
        }
        
        # $global:Ya360DepartmentsCache = $Ya360DepartReceived

        try {
            $global:Ya360DepartmentsCache = @{}
            foreach ( $cur in $( $Ya360DepartReceived ).psobject.BaseObject ) {
                $cur.id = [UInt64]$cur.id
                $cur.parentId = [UInt64]$cur.parentId
                $global:Ya360DepartmentsCache[[UInt64]$cur.id] = $cur
            }
        }
        catch {
            Write-Warning "Ошибка хэширования подразделений : $_"
            $global:Ya360DepartmentsCache = @{}
            throw
        }

    }
    # Тут имеем актуальный обновлённый кэш всех подразделений
    
    if  (! $parentId) {
        return $global:Ya360DepartmentsCache.values
    }

    $return = @($global:Ya360DepartmentsCache.values | Where-Object {$_.parentId -eq $parentId})
    if ($Recursive) {
        $ChildDepartments = @()
        foreach ( $cur in $return ) {
            try {
                $ChildDepartments += Get-Ya360DepartmentList -parentId $($cur.id) -Recursive -ErrorAction Stop
            }
            catch {
                Write-Error "Get-Ya360DepartmentList -parentId $($cur.id) : $_"
                throw
            }
        }
        $return += $ChildDepartments
    }
    
    return $return
}
