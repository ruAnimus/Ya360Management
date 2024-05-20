@{
    ModuleVersion = '0.1.0'
    Author = 'ruAnimus'
    CompanyName = 'UTMN'
    Description = 'Yandex 360 management module'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Connect-Ya360',
		'Get-Ya360UserList',
		'Get-Ya360User',
		'Get-Ya360UserMailRules',
		'Get-Ya360UserMailAddressBook',
		'Get-Ya360UserMailSenderInfo',
		'Set-Ya360UserMailSenderInfo',
		'Set-Ya360UserContacts',
		'Remove-Ya360UserContacts',
		'New-Ya360ContactObject',
		'Set-Ya360User',
		'New-Ya360UserObject',
		'Add-Ya360UserAlias',
		'Remove-Ya360UserAlias'
		)
    ModuleToProcess = 'Ya360Management.psd1'
}
