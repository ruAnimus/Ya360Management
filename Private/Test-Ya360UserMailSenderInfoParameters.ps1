function Test-Ya360UserMailSenderInfoParameters {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [PSCustomObject]$Signature
        )

    if ($Signature.PSObject.Properties.Name -eq "defaultFrom" -and
        $Signature.PSObject.Properties.Name -eq "fromName" -and
        $Signature.PSObject.Properties.Name -eq "signPosition" -and
        $Signature.PSObject.Properties.Name -eq "signs") {
            
            # Проверка типов свойств
            if ( ! ($Signature.defaultFrom -is [string] -and
                $Signature.fromName -is [string] -and
                $Signature.signPosition -is [string] -and
                $Signature.signs -is [array])) {
                # return $true
                Write-Error "Ошибка: Структура не соответствует ожидаемым типам данных."
                return $false
            }
        # Проверка свойства "signs"
        if ($Signature.signs -is [array] ) {
            foreach ($sign in $Signature.signs) {
                if ($sign.PSObject.Properties.Name -eq "emails" -and
                    $sign.PSObject.Properties.Name -eq "isDefault" -and
                    $sign.PSObject.Properties.Name -eq "lang" -and
                    $sign.PSObject.Properties.Name -eq "text") {

                        <# if ( -not (
                            $sign.emails -is [array] -and
                            $sign.emails.ForEach{ $_ -is [string] } -and
                            $sign.isDefault -is [boolean] -and
                            $sign.lang -is [string] -and
                            $sign.text -is [string]
                            ) ) {
                                Write-Error "Ошибка: Внутренняя структура 'signs' не соответствует ожидаемым типам данных."
                                return $false
                        } #>

                    continue
                } else {
                    Write-Error "Ошибка: Свойства внутренней структуры 'signs' не соответствуют ожидаемой структуре."
                    return $false
                }
            }
        } else {
            Write-Error "Ошибка: Свойство 'signs' должно быть массивом."
            return $false
        }
    } else {
        Write-Error "Ошибка: Структура не соответствует ожидаемой структуре."
        return $false
    }

    return $true
}
