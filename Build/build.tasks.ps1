# [InvokeBuild Configuration] -------------------------------------------------------------------------------------

Set-BuildHeader {
    param($Path)

    Write-Build Green ""
    Write-Build Green ('=' * 79)
    Write-Build Green "Task $Path : $(Get-BuildSynopsis $Task)"
    #Write-Build Yellow "At $($Task.InvocationInfo.ScriptName):$($Task.InvocationInfo.ScriptLineNumber)"

}

# Define footers similar to default but change the color to DarkGray.
Set-BuildFooter {
    param($Path)
    Write-Build Green ('-' * 79)
    Write-Build DarkGray "Done $Path, $($Task.Elapsed)"
}

# Synopsis: Runs before any task
Enter-Build {
    "$($moduleParams.ModuleName) Build"
    Write-Build Yellow "Importing Build Support Functions"
    . $prjBuildFunctionsPath
}

# [Tasks] ---------------------------------------------------------------------------------------------------------

# Synopsis: Alias Task for Build
Add-BuildTask Build Clean, SetEnvironment, BuildModule

# Synopsis: Alias Task for Test
Add-BuildTask Test SetEnvironment, TestModule

# Synopsis: Build PowerShell Module
Add-BuildTask BuildModule {

    $prjSrcPublicFunctionsPath = Join-Path -Path $prjSourcePath -ChildPath "Public"
    $prjSrcPrivateFunctionsPath = Join-Path -Path $prjSourcePath -ChildPath "Private"

    # Get Module Version from GitVersion
    $gitVersion = dotnet dotnet-gitversion | ConvertFrom-Json

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

    # Get Commit Messages
    $commitMsgs = Get-CommitsSinceLastTag -Path "$prjRoot"

    # Create Release Notes
    if ($gitVersion.PreReleaseTag) {
        $releaseNotes = $commitMsgs | New-ReleaseNotes -Version $gitversion.NuGetVersionV2
    }
    else {
        $releaseNotes = $commitMsgs | New-ReleaseNotes -Version $gitversion.NuGetVersionV2 -Release
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

    if ($gitVersion.PreReleaseTag) { $moduleManifestParams.add('Prerelease', $gitVersion.NuGetPreReleaseTagV2) }
    if ($releaseNotes) { $moduleManifestParams.add('ReleaseNotes', $releaseNotes) }

    # Copy Formats
    if ($moduleParams.FormatsToProcess) {
        # TODO: Add a way to copy multiple in order.
    }

    New-ModuleManifest @moduleManifestParams

}

# Synopsis: Clean up the target build directory
Add-BuildTask Clean {

    if ($(Test-Path -Path $prjBuildOutputPath) -eq $true) { Remove-Item –Path $prjBuildOutputPath –Recurse -Force }

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

    Set-BuildEnvironment -Path $prjRoot -VariableNamePrefix "SAM" -Force
    Get-BuildEnvironment -Path $prjRoot

    if ($ENV:GITHUB_ACTIONS) {

        # Git Version Variables
        $gitVersion = dotnet dotnet-gitversion | ConvertFrom-Json

        "::set-output name=gvFullSemVer::$($gitVersion.FullSemVer)"
        "::set-output name=gvSemVer::$($gitVersion.SemVer)"
        "::set-output name=gvMajorMinorPatch::$($gitVersion.MajorMinorPatch)"
        "::set-output name=gvNuGetVersionV2::$($gitVersion.NuGetVersionV2)"

        # Module Variables
        "::set-output name=prjModulePath::$mdlPath"
        "::set-output name=prjBuildOutput::$prjBuildOutputPath"
    }

}

# Synopsis: Run Pester Tests
Add-BuildTask TestModule {

    if ($ENV:GITHUB_ACTIONS) {
        $testResultsName = "TestResults-{0}-{1}-{2}.xml" -f $ENV:ImageOS, $PSVersionTable.PSEdition, $PSVersionTable.PSVersion
    }else{
        $testResultsName = "TestResults-{0}-{1}-{2}.xml" -f $PSVersionTable.OS, $PSVersionTable.PSEdition, $PSVersionTable.PSVersion
    }

    $prjTestResultPath = Join-Path -Path $prjBuildOutputPath -ChildPath $testResultsName

    if ($ENV:GITHUB_ACTIONS) {
        "::set-output name=pesterfile::$testResultsName"
        "::set-output name=pesterResults::$prjTestResultPath"
    }

    # Remove Any Pester Modules that are loaded
    Get-Module -Name Pester | Remove-Module -Force

    # Import Pester Module
    $pesterModulePath = Join-Path -Path $prjBuildDependenciesPath -ChildPath "Pester"

    if (Test-Path -Path $pesterModulePath) {

        Import-Module $pesterModulePath -Force

        # Configure Pester
        $configuration = [PesterConfiguration]::Default

        $configuration.Run.Path = $prjTestPath
        $configuration.Run.Exit = $true

        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputPath = $prjTestResultPath

        $configuration.output.Verbosity = 'Detailed'

        $r = Invoke-Pester -Configuration $configuration

        if ("Failed" -eq $r.Result) { throw "Run failed!" }

        ""
    }
    else {

        Write-Warning -Message "Missing Pester Module - Call Build.ps1 -InstallDependencies so save the module"

    }

}
