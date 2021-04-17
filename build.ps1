<#
	.SYNOPSIS
		Module Build wrapper for SAM.PSModule

	.NOTES
		Change Log:
			1.0.0 - 4/16/2021 (Zachary Shupp)

	.LINK
		https://github.com/zacharyshupp/SAM.PSModule
#>

# [Script Parameters] ---------------------------------------------------------------------------------------------

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Several Parameters are used in the .\build\module.tasks.ps1 file.'
)]
param (

	# Specifies if the Dependencies should be installed.
	[Parameter()]
	[switch]
	$InstallDependencies,

	# Specifies the powershell gallery to use.
	[Parameter()]
	[string]
	$GalleryRepository = "PSGallery",

	# Specifies the Tasks to run.
	[Parameter()]
	[string[]]
	$Task

)

# [Initialisations] -----------------------------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

#Add TLS 1.2 to potential security protocols on Windows Powershell. This is now required for powershell gallery
if ($PSEdition -eq 'Desktop') {
	[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 'Tls12'
}

# [Declarations] --------------------------------------------------------------------------------------------------

$requiredModules = @{
	Pester      = 'Latest'
	InvokeBuild = 'Latest'
}

$moduleParams = @{
	ModuleName       = "SAM.PSModule"
	Guid             = "973ef4d3-ffd9-4c56-b0e1-5b4b3b10730c"
	Author           = "Zachary Shupp"
	Description      = "PowerShell Module with useful functions."
	ProjectUri       = "https://github.com/zacharyshupp/SAM.PSModule"
	LicenseUri       = "https://github.com/zacharyshupp/SAM.PSModule/blob/main/LICENSE.md"
	Tags             = @('SAM')
	FormatsToProcess = @()
}

# Project Directories
$prjRoot = $PSScriptRoot
$prjBuildPath = Join-Path -Path $PSScriptRoot -ChildPath "Build"
$prjBuildOutputPath = Join-Path -Path $PSScriptRoot -ChildPath "BuildOutput"
$prjBuildDependenciesPath = Join-Path -Path $PSScriptRoot -ChildPath "BuildDependencies"
$prjDocsPath = Join-Path -Path $PSScriptRoot -ChildPath "Docs"
$prjSourcePath = Join-Path -Path $PSScriptRoot -ChildPath $moduleParams.ModuleName
$prjTestPath = Join-Path -Path $PSScriptRoot -ChildPath "Tests"

# Project Files
$prjBuildTaskPath = Join-Path -Path $prjBuildPath -ChildPath "build.tasks.ps1"
$prjTestResultPath = Join-Path -Path $prjBuildOutputPath -ChildPath "TestResults.xml"
$prjCodeCoveragePath = Join-Path -Path $prjBuildOutputPath -ChildPath "CodeCoverage.xml"

# Module Build Variables
$mdlPath = Join-Path -Path $prjBuildOutputPath -ChildPath $moduleParams.ModuleName
$mdlPSM1Path = Join-Path -Path $mdlPath -ChildPath "$($moduleParams.ModuleName)`.psm1"
$mdlPSD1Path = Join-Path -Path $mdlPath -ChildPath "$($moduleParams.ModuleName)`.psd1"

# [Execution] -----------------------------------------------------------------------------------------------------

if ($InstallDependencies) {

	# Remove Dependecies directory if it already exists.
	if ((Test-Path -Path $prjBuildDependenciesPath) -eq $true) {
		Remove-Item -Path $prjBuildDependenciesPath -Recurse -Force -Confirm:$false
	}

	# Find Gallery
	$gallery = Get-PSRepository -Name $GalleryRepository

	if ($gallery -and $gallery.InstallationPolicy -eq "Untrusted") {
		Set-PSRepository -Name $GalleryRepository -InstallationPolicy Trusted
	}
	elseif (!$gallery) {
		throw "Unable to find a PSRepository with the name '$GalleryRepository'"
	}

    # Save Modules
    $requiredModules.GetEnumerator() | ForEach-Object {

        Write-Verbose "Found '$($_.Key)' with a value of '$($_.Value)'"

        $galleryParams = @{
            Name        = $_.Key
            Force       = $true
            Path        = $prjBuildDependenciesPath
            ErrorAction = 'Stop'
        }

        if ($_.Value -ne 'Latest') { $gallaryParams.Add('RequiredVersion', $_.Value) }

        Save-Module @galleryParams

    }

	# If Gallery was orginally Untrusted set back.
	if ($gallery -and $gallery.InstallationPolicy -eq "Untrusted") {
		Set-PSRepository -Name $GalleryRepository -InstallationPolicy Untrusted
	}

}

if ($Task) {

	# Import InvokeBuild Module
	if (!(Get-Module -Name "InvokeBuild")) {

		$ibModulePath = Join-Path -Path $prjBuildDependenciesPath -ChildPath "InvokeBuild"
		Import-Module $ibModulePath -Global -ErrorAction Stop

	}

	# Invoke Build Tasks
	Invoke-Build -Result 'Result' -File $prjBuildTaskPath -Task $Task

    # Return error to CI
    if ($Result.Error) {

        $Error[-1].ScriptStackTrace | Out-String
        exit 1

    }

    exit 0

}
