<#
    .SYNOPSIS
    Ya360Management Module Loader
    
    .DESCRIPTION
    Loads all functions from Public and Private directories.
#>

$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 )

# Dot source all functions
foreach ($Import in @($Private + $Public)) {
    try {
        . $Import.FullName
    }
    catch {
        Write-Error "Failed to import function $($Import.Name): $_"
    }
}

# Export Public functions
Export-ModuleMember -Function $Public.BaseName
