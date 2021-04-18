
Set-BuildHeader {
	param($Path)
	Write-Build Green ('=' * 79)
	Write-Build Green "Task $Path : $(Get-BuildSynopsis $Task)"
	Write-Build Yellow "At $($Task.InvocationInfo.ScriptName):$($Task.InvocationInfo.ScriptLineNumber)"
}

# Define footers similar to default but change the color to DarkGray.
Set-BuildFooter {
	param($Path)
    Write-Build Green ('=' * 79)
	Write-Build DarkGray "Done $Path, $($Task.Elapsed)"
}

# Synopsis: Runs before any task
Enter-Build {
	"Entering Build process"
}

# Synopsis: Alias Task for Build
Add-BuildTask Build Clean, BuildModule, CreateModuleArchive

# Synopsis: Clean up the target build directory
Add-BuildTask Clean {

	if ($(Test-Path -Path $prjBuildOutputPath) -eq $true) { Remove-Item –Path $prjBuildOutputPath –Recurse -Force }

}

# Synopsis: Build Module
Add-BuildTask BuildModule {

	$prjSrcPublicFunctionsPath = Join-Path -Path $prjSourcePath -ChildPath "Public"
	$prjSrcPrivateFunctionsPath = Join-Path -Path $prjSourcePath -ChildPath "Private"

	# Get Module Version from GitVersion
	$gitVersion = dotnet-gitversion | ConvertFrom-Json

    # Create Module Buildoutput Directory
    New-Item -Path $mdlPath -ItemType Directory -Force | Out-Null

    $outParams = @{
        FilePath = $mdlPSM1Path
        Append   = $true
        Encoding = 'utf8'
        Force    = $true
    }

    # Retrieve module variables if it exists
    $sourceVarPath = Join-Path -Path $prjSourcePath -ChildPath "$($moduleParams.ModuleName).variables.ps1"

    if ((Test-Path -Path $sourceVarPath) -eq $true) { Get-Content -Path $sourceVarPath | Out-File @outParams }

    # Retrieve functions
    $params = @{
        Recurse     = $true
        ErrorAction = "SilentlyContinue"
        filter      = "*.ps1"
    }

    $publicFiles = @(Get-ChildItem -Path $prjSrcPublicFunctionsPath @params)
    $privateFiles = @(Get-ChildItem -Path $prjSrcPrivateFunctionsPath @params)

    # Build PSM1 file with all the functions
    foreach ($file in @($publicFiles + $privateFiles)) {

        $params = @{
            FilePath = $mdlPSM1Path
            Append   = $true
            Encoding = 'utf8'
            Force    = $true
        }

        Get-Content -Path $($file.fullname) | Out-File @params

    }

    # Create PSD1
    # Build PSD1 file with all the module Information
    $moduleManifestParams = @{
        Author            = $moduleParams.Author
        Description       = $moduleParams.Description
        Copyright         = "(c) $((Get-Date).year) $($moduleParams.Author). All rights reserved."
        Path              = $mdlPSD1Path
        Guid              = $moduleParams.Guid
        FunctionsToExport = $publicFiles.basename
        VariablesToExport = '*'
        Rootmodule        = "$($moduleParams.ModuleName).psm1"
        ModuleVersion     = $gitVersion.MajorMinorPatch
        LicenseUri        = $moduleParams.LicenseUri
        ProjectUri        = $moduleParams.ProjectUri
        Tags              = $moduleParams.Tags
    }

    # Copy Formats
    if ($moduleParams.FormatsToProcess) {
        # TODO: Add a way to copy multiple in order.
    }

    New-ModuleManifest @moduleManifestParams

}

# Synopsis: Creates an zip file for the module
Add-BuildTask CreateModuleArchive {

    $gitVersion = dotnet-gitversion | ConvertFrom-Json

    $archiveName = "{0}-{1}.zip" -f $moduleParams.ModuleName, $gitVersion.NuGetVersionV2
    $archivePath = Join-Path -Path $prjBuildOutputPath -ChildPath $archiveName

    if (Test-Path $archivePath) { Remove-Item -Path $archivePath -Force -ErrorAction Stop }

    Get-ChildItem -Path $prjBuildOutputPath | Compress-Archive -DestinationPath $archivePath -CompressionLevel Optimal

    if ($ENV:GITHUB_ACTIONS) {
        "::set-output name=prjArchivePath::$archivePath"
        "::set-output name=prjArchiveName::$archiveName"
    }

}

# Synopsis: Creates an zip file for the module
Add-BuildTask SetEnvironment {

    Get-ChildItem -Path $prjBuildDependenciesPath -Attributes "directory" | ForEach-Object {

        $module = $_.BaseName
        $modulePath = Join-Path -Path $prjBuildDependenciesPath -ChildPath $module

        # Clear any modules with already loaded
        Get-Module -Name $module | Remove-Module -Force

        $import = Import-Module $modulePath -PassThru -Global

        "Imported '$module' version '$($import.Version)'"

    }

    if ($ENV:GITHUB_ACTIONS) {

        # Git Version Variables
        $gitVersion = dotnet-gitversion | ConvertFrom-Json

        "::set-output name=gvFullSemVer::$($gitVersion.FullSemVer)"
        "::set-output name=gvSemVer::$($gitVersion.SemVer)"
        "::set-output name=gvMajorMinorPatch::$($gitVersion.MajorMinorPatch)"
        "::set-output name=gvNuGetVersionV2::$($gitVersion.NuGetVersionV2)"

        # Module Variables
        "::set-output name=prjModulePath::$mdlPath"
        "::set-output name=prjBuildOutput::$prjBuildOutputPath"
        "::set-output name=prjTestResultPath::$prjTestResultPath"
        "::set-output name=prjCodeCoveragePath::$prjCodeCoveragePath"
    }

}
