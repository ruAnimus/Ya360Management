@{
	# Script module or binary module file associated with this manifest.
	RootModule        = 'Ya360Management.psm1'
    
	# Version number of this module.
	ModuleVersion     = '0.1.0'
    
	# ID used to uniquely identify this module
	GUID              = '2b629471-7681-42e5-94ae-3b680789d311'
    
	# Author of this module
	Author            = 'ruAnimus'
    
	# Company or vendor of this module
	CompanyName       = 'UTMN'
    
	# Copyright statement for this module
	Copyright         = '(c) 2025 ruAnimus. All rights reserved.'
    
	# Description of the functionality provided by this module
	Description       = 'Yandex 360 management module'
    
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.1'
    
	# Modules that must be imported into the global environment prior to importing this module
	# RequiredModules = @()
    
	# Assemblies that must be loaded prior to importing this module
	# RequiredAssemblies = @()
    
	# Script files (.ps1) that are run in the caller's environment prior to importing this module.
	# ScriptsToProcess = @()
    
	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @()
    
	# Format files (.ps1xml) to be loaded when importing this module
	# FormatsToProcess = @()
    
	# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
	# NestedModules = @()
    
	# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
	FunctionsToExport = @(
		'Connect-Ya360',
		'Get-Ya360UserList',
		'Get-Ya360User',
		'Get-Ya360UserMailRules',
		'Get-Ya360UserMailAddressBook',
		'Get-Ya360UserMailSenderInfo',
		'Set-Ya360UserMailSenderInfo',
		'Set-Ya360UserContacts',
		'Remove-Ya360UserContacts',
		'Set-Ya360User',
		'Add-Ya360UserAlias',
		'Remove-Ya360UserAlias',
		'Set-Ya360UserPhoto',
		'Get-Ya360AuditLogDisk',
		'Get-Ya360DepartmentList',
		'Get-Ya360Department',
		'Set-Ya360Department',
		'New-Ya360Department',
		'Remove-Ya360Department',
		'New-Ya360ContactObject',
		'New-Ya360UserObject'
	)
    
	# Cmdlets to export from this module
	CmdletsToExport   = @()
    
	# Variables to export from this module
	VariablesToExport = @()
    
	# Aliases to export from this module
	AliasesToExport   = @()
    
	# DscResources to export from this module
	# DscResourcesToExport = @()
    
	# List of all modules packaged with this module
	# ModuleList = @()
    
	# List of all files packaged with this module
	# FileList = @()
    
	# Private data to pass to the module specified in RootModule/ModuleToProcess
	PrivateData       = @{
		PSData = @{
			# Tags = @()
			# LicenseUri = ''
			# ProjectUri = ''
			# IconUri = ''
			# ReleaseNotes = ''
		}
	}
    
	# HelpInfo URI of this module
	# HelpInfoURI = ''
    
	# Default prefix for commands exported from the module. Override the default prefix using Import-Module -Prefix.
	# DefaultCommandPrefix = ''
}
