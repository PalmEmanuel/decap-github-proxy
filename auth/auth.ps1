using namespace System.Net

param($Request, $TriggerMetadata)

$State = "$(Get-Random)"[0..7] -join ''
$Scope = 'repo,user'

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::MovedPermanently
    Headers = @{
        Location = "https://github.com/login/oauth/authorize?client_id=$env:GITHUB_CLIENT_ID&redirect_uri=$env:CALLBACK_REDIRECT_URI&scope=$Scope&response_type=code&state=$State"
    }
})