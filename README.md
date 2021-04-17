# SAM.PSModule

Test PowerShell Module with GitVersion, GitReleaseManager, and GitHub Actions for deployment.

## Branching

- The ***main*** branch is the primary branch and can be released at any time.

## Releases

- Releases are triggered with release branches created from main. This allows for release notes to be generated and perform final testing.
- Release branches should be named 'release/v<version>'.
- In a release version, GitVersion will tag the release with -rc so its easy to track its a prerelease until this is merged into main.
