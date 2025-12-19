function Get-Ya360AuditLogDisk {
    param (
        # Количество событий на странице. Максимальное значение — 100.
            [Parameter(
                Position=0,
                HelpMessage="Количество событий на странице. Максимальное значение — 100.")
            ]
            [ValidateNotNullOrEmpty()]
            [Int64]
        $PageSize = 10,

        # Токен постраничной навигации.
            [Parameter(
                HelpMessage="Токен постраничной навигации.")
            ]
            [ValidateNotNullOrEmpty()]
            [string]
        $PageToken,

        # Верхняя граница периода выборки в формате ISO 8601, например 2022-12-31T23:59:59+03:00 или 2022-12-31T12:00:00Z. Значение по умолчанию — текущее время.
            [Parameter(
                HelpMessage="Верхняя граница периода выборки в формате ISO 8601, например 2022-12-31T23:59:59+03:00 или 2022-12-31T12:00:00Z. Значение по умолчанию — текущее время.")
            ]
            [ValidateNotNullOrEmpty()]
            [string]
        $BeforeDate,

        # Нижняя граница периода выборки в формате ISO 8601, например 2022-12-31T23:59:59+03:00 или 2022-12-31T12:00:00Z.
            [Parameter(
                HelpMessage="Нижняя граница периода выборки в формате ISO 8601, например 2022-12-31T23:59:59+03:00 или 2022-12-31T12:00:00Z.")
            ]
            [ValidateNotNullOrEmpty()]
            [string]
        $AfterDate,

        # Список пользователей, действия которых должны быть включены в список событий.
            [Parameter(
                HelpMessage="Список пользователей, действия которых должны быть включены в список событий.")
            ]
            [ValidateNotNullOrEmpty()]
            [string[]]
        $IncludeUids,

        # Список пользователей, действия которых должны быть исключены из списка событий.
            [Parameter(
                HelpMessage="Список пользователей, действия которых должны быть исключены из списка событий.")
            ]
            [ValidateNotNullOrEmpty()]
            [string[]]
        $ExcludeUids
    )

    if (! $global:Ya360Connected) {
        Write-Error "Подключение к Ya360 не выполнено, используйте Connect-Ya360"
        return
    }
    
    <# Примеры параметров
        $pageToken = "yourPageToken",
        $beforeDate = "2023-01-01T00:00:00Z",
        $afterDate = "2023-01-01T00:00:00Z",
        $includeUids = @("uid1", "uid2"),
        $excludeUids = @("uid3", "uid4")
    #>

    $uri = "https://api360.yandex.net/security/v1/org/$Ya360OrgID/audit_log/disk"
        # "?pageSize=$pageSize"
        # "&pageToken=$pageToken" +
        # "&beforeDate=$beforeDate" +
        # "&afterDate=$afterDate" +
        # "&includeUids=$includeUids" +
        # "&excludeUids=$excludeUids"

    try {
        if ($pageSize -gt 100 ) {$pageSize = 100}
            $uri += "?pageSize=$pageSize"
        if ($pageToken) {
            $uri += "&pageToken=$pageToken"
        }
        if ($beforeDate) {
            $beforeDate = Get-Date $beforeDate -UFormat '+%Y-%m-%dT%H:%M:%S.00Z' -ErrorAction Stop
            $uri += "&beforeDate=$beforeDate"
        }
        if ($afterDate) {
            $afterDate = Get-Date $afterDate -UFormat '+%Y-%m-%dT%H:%M:%S.00Z' -ErrorAction Stop
            $uri += "&afterDate=$afterDate"
        }
        if ($includeUids) {
            $includeUids = $($includeUids -join ',')
            $uri += "&includeUids=$includeUids"
        }
        if ($excludeUids) {
            $excludeUids = $($excludeUids -join ',')
            $uri += "&excludeUids=$excludeUids"
        }
    }
    catch {
        Write-Error "Параметры не корректны: $_"
        throw
    }


    try {

        $Ya360Responce = Invoke-WebRequest -Uri $uri `
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
        Write-Error "Ошибка при запросе Invoke-WebRequest: $_"
        throw
    }
}
