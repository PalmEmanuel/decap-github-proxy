# Decap CMS OAuth Proxy for GitHub with Azure Functions

A solution to handle least privilege authentication for proxying GitHub authentication when using Decap CMS.

The key is to use a GitHub app, not an OAuth app, to authenticate users. This way, the app can be granted fine-grained permissions for the specific repository to perform the required actions.

## Azure Function

The functions are intentionally marked as anonymous, as the code itself isn't sensitive. The validation is done by the registered GitHub application.

## Tooling and Links

- [Azure Functions Documentation](https://learn.microsoft.com/en-us/azure/azure-functions/)
- [Visual Studio Code](https://aka.ms/vscode)
- [Azure Functions - Extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)
- [Azurite (Local Azure Storage Emulator) - Extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=Azurite.azurite)
- [Bicep - Extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)
- [Azure Functions Core Tools CLI (Comes with VSCode Extension)](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local)
- [PowerShell](https://github.com/PowerShell/PowerShell)
