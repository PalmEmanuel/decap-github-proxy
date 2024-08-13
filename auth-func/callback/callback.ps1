using namespace System.Net

param($Request, $TriggerMetadata)

$Request | ConvertTo-Json | Write-Information

# Get authorization $Code from request parameters
$Code = $Request.Query['code']

$Status = 'success'
$TokenBody = @{
    client_id = $env:GitHubClientId
    client_secret = $env:GitHubClientSecret
    code = $Code
} | ConvertTo-Json
$Headers = @{
    'Accept' = 'application/json'
}
$TokenResponse = Invoke-RestMethod "https://github.com/login/oauth/access_token" -Body $TokenBody -Method Post -ContentType "application/json" -Headers $Headers -ErrorAction Stop
$Token = $TokenResponse.access_token
$Content = @{
    token = $Token
    provider = 'github'
} | ConvertTo-Json -Compress

$Body = @"
<html>
<head>
	<script>
		const receiveMessage = (message) => {
			window.opener.postMessage(
				'authorization:github:${Status}:${Content}',
				'*'
			);
			window.removeEventListener("message", receiveMessage, false);
		}
		window.addEventListener("message", receiveMessage, false);
		window.opener.postMessage("authorizing:github", "*");
	</script>
	<body>
		<p>Authorizing Decap CMS...</p>
	</body>
</head>
</html>
"@

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $Body
    ContentType = "text/html"
})