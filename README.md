# Azure Container Instances with Aure Developer CLI

This repo contains a demo for Azure Container Apps which can be deployed to Azure with the [Aure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/overview). This template is part of the [Microsoft Trainer Demo Deploy Catalog](https://aka.ms/trainer-demo-deploy).

## ⬇️ Installation
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
    - When installing the above the following tools will be installed on your machine as well:
        - [GitHub CLI](https://cli.github.com)
        - [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
- [.NET Core 8 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)

## 🚀 Usage
- Clone this repo
- Execute following command and follow instructions in CLI
```
azd up
```

- Use the [demo guide](demoguide.md) for inspiration for your demo

### ⚠️ Attention non-Windows users!
This scenario has been tested exclusively on a Windows machine. Behavior on other platforms, such as Linux, may differ due to platform-specific considerations. For instance, the function app runs on Windows while being built locally and deployed to the function. 
If you are testing or deploying on a non-Windows platform, consider validating the application's behavior in your environment and adjusting configurations as necessary.

## 💭 Feedback and Contributing
Feel free to create issues for bugs, suggestions or create a PR with new demo scenario's 