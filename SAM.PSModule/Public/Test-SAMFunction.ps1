function Test-SAMFunction {

	<#
		.SYNOPSIS
			Short description

		.DESCRIPTION
			Long description

		.EXAMPLE
			PS C:\> Test-SAMFunction -Text "This is a test"

			This example shows how to call the functions

		.INPUTS
			Inputs (if any)

		.OUTPUTS
			Output (if any)

		.NOTES
			General notes

		.LINK
			HTTPS://WWW.GOOGLE.COM
	#>

	[CmdletBinding()]
	param (

		# Specify the String to Echo
		[Parameter(Mandatory)]
		[String]
		$Text

	)

	begin {

	}

	process {

	}

	end {

		Write-Output $(Set-TextTest -Text $Text)

	}

}
