# Azure/Entra Role Elevation Script

This PowerShell script enables role elevation using Privileged Identity Management (PIM) in either **Azure Resources** or **Microsoft Entra** (formerly Azure Active Directory). It supports both interactive and non-interactive modes, allowing users to either select roles from a list or bypass selection by specifying a role directly.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
  - [PowerShell Version](#powershell-version)
  - [Required Modules](#required-modules)
  - [Creating an App in Entra](#creating-an-app-in-entra)
- [Installation and Setup](#installation-and-setup)
- [Usage](#usage)
  - [Interactive Mode](#interactive-mode)
  - [Non-Interactive Mode](#non-interactive-mode)
    - [Entra Role Elevation Example](#entra-role-elevation-example)
    - [Azure Resources Elevation Example](#azure-resources-elevation-example)
- [Script Functions Overview](#script-functions-overview)
- [Troubleshooting](#troubleshooting)
- [References and Links](#references-and-links)
- [License](#license)

---

## Overview

This script is designed to automate role elevation through PIM by leveraging Microsoft Graph and Azure PowerShell modules. It performs the following tasks:
- Checks for and installs required PowerShell modules.
- Logs into Microsoft Graph (for Entra role operations) and Azure (for Azure resource role operations) using device authentication.
- Prompts users for inputs such as role selection, duration, and justification.
- Activates the selected role using either Entra PIM or Azure PIM methods.

---

## Prerequisites

### PowerShell Version

- Ensure you are running PowerShell 5.1 or PowerShell 7.x. It is recommended to use the latest version to avoid compatibility issues.

### Required Modules

**Note: At the time of writing this script, certain latest versions of the modules below had bugs when testing this script, that is the reason for the version lock here**

The script automatically checks for and installs the following modules with specified versions:

- **Microsoft Graph Modules**
  - `Microsoft.Graph.Users` (v2.21.1)
  - `Microsoft.Graph.Authentication` (v2.21.1)
  - `Microsoft.Graph.Identity.Governance` (v2.21.1)
- **Azure Modules**
  - `Az.Accounts` (v3.0.2)
  - `Az.Resources` (v7.2.0)

If the modules are not installed, the script will attempt to install them either system-wide (admin privileges) or for the current user.

### Creating an App in Entra

Before running the script for Entra role elevation, you must create an application in Microsoft Entra to allow device authentication with Microsoft Graph. Follow these steps:

1. **Sign in to the Azure Portal:**  
   Go to [https://portal.azure.com](https://portal.azure.com).

2. **Navigate to Azure Active Directory (Microsoft Entra):**  
   Click on **Azure Active Directory** in the left-hand navigation pane.

3. **Register a New Application:**  
   - Select **App registrations** and click on **New registration**.
   - **Name:** Provide a meaningful name (e.g., `PIM Role Elevation App`).
   - **Supported Account Types:** Choose the account types that apply to your scenario.
   - **Redirect URI:** For device authentication, this can typically be left blank.
   - Click **Register**.

4. **Note the App Information:**  
   - **Application (client) ID:** This is your `AppId`.
   - **Directory (tenant) ID:** This is your `TenantId`.

5. **API Permissions:**  
   - Go to the **API permissions** section of your registered app.
   - Add permissions for Microsoft Graph, including:
     - `RoleManagement.ReadWrite.Directory`
     - `User.Read`
   - **Grant admin consent** if required.

For more details, refer to the official documentation on [Registering an Application with Microsoft Entra](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app) and [Microsoft Graph Authentication](https://learn.microsoft.com/en-us/graph/auth-overview).

---

## Installation and Setup

1. **Download the Script:**
   - Save the script as `pim.ps1` in your desired directory.

2. **Execution Policy:**
   - Ensure that your PowerShell execution policy allows running scripts. You can check your policy with:
     ```powershell
     Get-ExecutionPolicy
     ```
   - If needed, set the policy to allow script execution (e.g., for the current session):
     ```powershell
     Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
     ```

3. **Required Module Installation:**
   - The script automatically installs the required modules if they are not present. Alternatively, you can manually install them using:
     ```powershell
     Install-Module -Name Microsoft.Graph.Users -RequiredVersion 2.21.1
     Install-Module -Name Microsoft.Graph.Authentication -RequiredVersion 2.21.1
     Install-Module -Name Microsoft.Graph.Identity.Governance -RequiredVersion 2.21.1
     Install-Module -Name Az.Accounts -RequiredVersion 3.0.2
     Install-Module -Name Az.Resources -RequiredVersion 7.2.0
     ```

---

## Usage

Run the script from a PowerShell prompt. There are two primary modes:

### Interactive Mode

Simply run the script without any parameters:
```powershell
./pim.ps1
```

### Non-Interactive Mode

You can supply parameters to bypass interactive prompts.

#### Entra Role Elevation Example:
```powershell
./pim.ps1 -Bypass "Global Administrator" -RoleType "Entra Roles"
```

	•	-Bypass: Directly selects the specified role.
	•	-RoleType: Specifies that the role is an Entra role.

 #### Azure Resources Elevation Example:
 ```powershell
./pim.ps1 -Bypass "Owner" -RoleType "Azure Resources" -ScopeType "Management Groups" -ScopeName "Tenant Root Group"
```

-Bypass: Directly selects the specified role.
-RoleType: Specifies that the role is for Azure resources.
-ScopeType: Specifies the level of the scope (Management Groups, Subscriptions, or Resource Groups).
-ScopeName: The friendly name of the selected scope.

---
## Script Functions Overview
- Show-Help:
  Displays help information including a description of parameters and examples.
- Install-RequiredModules:
Checks for, installs, and imports the required PowerShell modules needed for the script.
- Graph-Login:
Authenticates to Microsoft Graph using device authentication. Prompts for your App ID and Tenant ID if not already logged in.
- Az-Login:
Authenticates to Azure using device authentication.
- Get-UserSelection:
Provides a paginated interactive selection list from which the user can choose roles, subscriptions, resource groups, etc.
- Entra-Elevation:
Handles role activation for Entra PIM. Queries available roles, prompts for selection (unless bypassed), and activates the selected role via Microsoft Graph.
- Az-Elevation:
Handles role activation for Azure PIM. Queries available eligible roles within a specified scope and activates the selected role.
- main:
The main entry point that sets up module installation, logins, and routes to the appropriate elevation function based on the selected role type.

---

## Troubleshooting
- Module Installation Issues:
- If you encounter errors while installing modules, try running PowerShell as an Administrator or install the module for the current user using the -Scope CurrentUser parameter.
- Authentication Problems:
- Ensure that your device has internet connectivity.
- Double-check the App ID and Tenant ID entered when prompted during Microsoft Graph login.
- Verify that your registered app in Entra has the correct API permissions and that admin consent has been granted if necessary.
- Role Not Found or Eligibility Issues:
- If a role specified with the -Bypass parameter isn’t found, ensure that your account has eligibility for that role in PIM.
- For Azure resources, ensure that the scope provided (Management Groups, Subscriptions, or Resource Groups) is correct and that you have the necessary permissions.

---

## References and Links
- Microsoft Graph Documentation:
https://learn.microsoft.com/en-us/graph/overview
- Registering an App with Microsoft Entra (Azure AD):
https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app
- Microsoft Graph Authentication:
https://learn.microsoft.com/en-us/graph/auth-overview
- Privileged Identity Management (PIM) Overview:
https://learn.microsoft.com/en-us/azure/active-directory/privileged-identity-management/overview
- Azure PowerShell Documentation:
https://learn.microsoft.com/en-us/powershell/azure/
- Microsoft Graph PowerShell SDK:
https://github.com/microsoftgraph/msgraph-sdk-powershell

---
## License

This script is provided “as is” without warranty of any kind. You are free to use, modify, and distribute it as per your needs.

_For any questions or contributions, please feel free to open an issue or submit a pull request._
