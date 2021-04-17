function Set-TextTest {

	<#
		.SYNOPSIS
			Short description

		.DESCRIPTION
			Long description

		.EXAMPLE
			PS C:\> <example usage>
			Explanation of what the example does

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
		
		write-output "Text Passed: $Text"
		
	}
}