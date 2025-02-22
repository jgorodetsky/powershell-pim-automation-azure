<#
.SYNOPSIS
   Script for Role Elevation in Azure or Entra using PowerShell.


.DESCRIPTION
   This script allows users to elevate their roles either in Azure Resources or Entra.
   It supports both interactive and non-interactive modes by accepting parameters.


.PARAMETER Help
   Displays help information for the script.


.PARAMETER Bypass
   Specifies the role to bypass interactive selection and directly activate.


.PARAMETER RoleType
   Specifies the type of role to activate: "Entra Roles" or "Azure Resources".


.PARAMETER ScopeType
   Specifies the scope type for Azure Resources: "Management Groups", "Subscriptions", or "Resource Groups".


.PARAMETER ScopeName
   Specifies the friendly name of the scope for Azure Resources.


.EXAMPLE
   Interactive Mode:
       ./pim.ps1


   Non-Interactive Mode:
   Entra Example:
       ./pim.ps1 -Bypass "Global Administrator" -RoleType "Entra Roles"   
  
   Azure Resources Example:
       ./pim.ps1 -Bypass "Owner" -RoleType "Azure Resources" -ScopeType "Management Groups" -ScopeName "Tenant Root Group"
      
#>


param (
   [switch]$Help,
   [string]$Bypass,
   [ValidateSet("Entra Roles", "Azure Resources")]
   [string]$RoleType,
   [ValidateSet("Management Groups", "Subscriptions", "Resource Groups")]
   [string]$ScopeType,
   [string]$ScopeName
)


# Function to display help information
function Show-Help {
   <#
   .SYNOPSIS
       Displays help information for the script.


   .DESCRIPTION
       Provides instructions on how to use the script, including available parameters and examples.
   #>


   # Header
   Write-Host "Script for Role Elevation in Azure or Entra using PowerShell." -ForegroundColor Cyan
   Write-Host "============================================================" -ForegroundColor Cyan
   Write-Host ""


   # Description
   Write-Host "DESCRIPTION:" -ForegroundColor Yellow
   Write-Host "    This script allows users to elevate their roles either in Azure Resources or Entra." -ForegroundColor White
   Write-Host "    It supports both interactive and non-interactive modes by accepting parameters." -ForegroundColor White
   Write-Host ""


   # Parameters
   Write-Host "PARAMETERS:" -ForegroundColor Yellow
   Write-Host "    -Help" -ForegroundColor Green
   Write-Host "        Displays this help information." -ForegroundColor White
   Write-Host ""
   Write-Host "    -Bypass <RoleName>" -ForegroundColor Green
   Write-Host "        Specifies the role to bypass interactive selection and directly activate." -ForegroundColor White
   Write-Host ""
   Write-Host "    -RoleType <Entra Roles|Azure Resources>" -ForegroundColor Green
   Write-Host "        Specifies the type of role to activate." -ForegroundColor White
   Write-Host ""
   Write-Host "    -ScopeType <Management Groups|Subscriptions|Resource Groups>" -ForegroundColor Green
   Write-Host "        Specifies the scope type for Azure Resources (required for Azure role elevation)." -ForegroundColor White
   Write-Host ""
   Write-Host "    -ScopeName <Name>" -ForegroundColor Green
   Write-Host "        Specifies the friendly name of the scope for Azure Resources (required for Azure role elevation)." -ForegroundColor White
   Write-Host ""


   # Examples
   Write-Host "EXAMPLES:" -ForegroundColor Yellow
   Write-Host "    Interactive Mode:" -ForegroundColor Green
   Write-Host "        ./pim.ps1" -ForegroundColor White
   Write-Host ""
   Write-Host "    Non-Interactive Mode:" -ForegroundColor Green
   Write-Host "        ./pim.ps1 -Bypass `"Owner`" -RoleType `"Azure Resources`" -ScopeType `"Management Groups`" -ScopeName `"Tenant Root Group`"" -ForegroundColor White
   Write-Host ""
}


function Install-RequiredModules {
   <#
   .SYNOPSIS
       Checks, installs, and imports required PowerShell modules.


   .DESCRIPTION
       Ensures that the necessary PowerShell modules are installed with specific versions and imported for script execution.
   #>


   # Define the required modules and their versions
   $requiredModules = @(
       @{Name = "Microsoft.Graph.Users"; Version = "2.21.1"},
       @{Name = "Microsoft.Graph.Authentication"; Version = "2.21.1"},
       @{Name = "Microsoft.Graph.Identity.Governance"; Version = "2.21.1"},
       @{ Name = "Az.Accounts"; Version = "3.0.2" },
       @{ Name = "Az.Resources"; Version = "7.2.0" }
   )


   # Iterate over each required module
   foreach ($module in $requiredModules) {
       $moduleName = $module.Name
       $requiredVersion = [Version]$module.Version


       Write-Host "Checking for $moduleName module version $requiredVersion..." -ForegroundColor Cyan


       # Check if the required version of the module is available
       $installedModule = Get-Module -ListAvailable -Name $moduleName | Where-Object { $_.Version -eq $requiredVersion }


       if (-not $installedModule) {
           Write-Host "$moduleName module version $requiredVersion is not installed. Attempting to install..." -ForegroundColor Cyan
           try {
               Install-Module -Name $moduleName -RequiredVersion $requiredVersion -Force -ErrorAction Stop
               Write-Host "$moduleName module version $requiredVersion installed successfully." -ForegroundColor Green
           } catch {
               Write-Warning "Failed to install $moduleName module with admin privileges. Trying to install for the current user only..."
               try {
                   Install-Module -Name $moduleName -RequiredVersion $requiredVersion -Scope CurrentUser -Force -ErrorAction Stop
                   Write-Host "$moduleName module version $requiredVersion installed for the current user." -ForegroundColor Green
               } catch {
                   Write-Error "Failed to install $moduleName module: $_"
                   continue
               }
           }
       } else {
           Write-Host "$moduleName module version $requiredVersion is already installed." -ForegroundColor Yellow
       }


       # Check if the module is loaded in the current session
       # $moduleSpecification = @{ ModuleName = $moduleName; ModuleVersion = $requiredVersion }
       $importedModule = Get-InstalledModule -Name $moduleName | Where-Object { $_.Version -eq $requiredVersion }


       if (-not ($importedModule)) {
           Write-Host "$moduleName module version $requiredVersion is installed but not loaded. Importing..." -ForegroundColor Yellow
           try {
               Import-Module -Name $moduleName -RequiredVersion $requiredVersion -Force
               Write-Host "$moduleName module version $requiredVersion imported successfully." -ForegroundColor Green
           } catch {
               Write-Error "Failed to import ${moduleName} module version ${requiredVersion}: $($_.Exception.Message)"
           }
       } else {
           Write-Host "$moduleName module version $requiredVersion is already loaded." -ForegroundColor Yellow
       }
   }
}




function Get-UserSelection {
   <#
   .SYNOPSIS
       Prompts the user to select an item from a list.


   .PARAMETER items
       An array of items to display for selection.


   .PARAMETER prompt
       The prompt message to display to the user.


   .PARAMETER pageSize
       The number of items to display per page.
   #>
   param (
       [array]$items,
       [string]$prompt,
       [int]$pageSize = 22
   )


   $currentPage = 0
   $totalPages = [math]::Ceiling($items.Count / $pageSize) - 1


   # Determine the property to display based on the type of items
   $displayProperty = if ($items -and $items[0].PSObject.Properties['DisplayName']) {
       'DisplayName'
   } elseif ($items -and $items[0].PSObject.Properties['RoleDefinitionDisplayName']) {
       'RoleDefinitionDisplayName'
   } elseif ($items -and $items[0].PSObject.Properties['ResourceGroupName']) {
       'ResourceGroupName'
   } elseif ($items -and $items[0].PSObject.Properties['Name']) {
       'Name'
   } elseif ($items -and $items[0].RoleDefinition -and $items[0].RoleDefinition.PSObject.Properties['DisplayName']) {
       'RoleDefinition.DisplayName'
   } else {
       Write-Host "Unable to determine display property for items." -ForegroundColor Red
       return $null
   }


   do {
       Clear-Host
       Write-Host "$prompt (Page $(($currentPage + 1)) of $(($totalPages + 1))):"
       $start = $currentPage * $pageSize
       $end = [math]::Min($start + $pageSize, $items.Count) - 1
       $pagedItems = $items[$start..$end]


       for ($i = 0; $i -lt $pagedItems.Count; $i++) {
           # Check if the display property is a nested property
           if ($displayProperty -eq 'RoleDefinition.DisplayName') {
               # Access the nested DisplayName
               $displayName = $pagedItems[$i].RoleDefinition.DisplayName
           } else {
               # Access a top-level property
               $displayName = $pagedItems[$i].$displayProperty
           }
           Write-Host "$($i + 1): $displayName"
       }


       Write-Host "`n0: Show more"
       Write-Host "P: Previous page"
       Write-Host "Q: Quit selection"


       $selection = Read-Host "Select the number corresponding to your choice"
       switch ($selection.ToUpper()) {
           '0' { if ($currentPage -lt $totalPages) { $currentPage++ } }
           'P' { if ($currentPage -gt 0) { $currentPage-- } }
           'Q' { return $null }
           default {
               $index = $selection - 1
               if ($index -ge 0 -and $index -lt $pagedItems.Count) {
                   return $pagedItems[$index]
               } else {
                   Write-Host "Invalid selection. Please try again." -ForegroundColor Red
               }
           }
       }
   } while ($true)
}


function Graph-Login {
   <#
   .SYNOPSIS
       Logs into Microsoft Graph.


   .DESCRIPTION
       Checks and logs into Microsoft Graph using device authentication if not already logged in.
   #>
   $graphNeedLogin = $true
   try {
       $graphContext = Get-MgContext
       if ($graphContext) {
           $graphNeedLogin = [string]::IsNullOrEmpty($graphContext.Account)
           if (-not $graphNeedLogin) {
               Write-Host "Already logged in to Microsoft Graph as $($graphContext.Account)" -ForegroundColor Green
           }
       }
   } catch {
       Write-Warning "No Microsoft Graph context found. Need to login."
   }


   if ($graphNeedLogin) {
       Write-Host "Logging into Microsoft Graph..." -ForegroundColor Yellow
      # Securely request AppId and TenantId from user input
       $AppId = Read-Host "Enter your App ID"
       $TenantId = Read-Host "Enter your Tenant ID"
       try {
           Connect-MgGraph -AppId $AppId -TenantId $TenantId -UseDeviceAuthentication
           $graphContext = Get-MgContext
           Write-Host "Successfully logged into Microsoft Graph as $($graphContext.Account)" -ForegroundColor Green
       } catch {
           Write-Error "Failed to log into Microsoft Graph: $_"
           return $false
       }
   }
   return $graphcontext
}


function Az-Login {
   <#
   .SYNOPSIS
       Logs into Azure.


   .DESCRIPTION
       Checks and logs into Azure using device authentication if not already logged in.
   #>
   $azureNeedLogin = $true
   try {
       $azureContext = Get-AzContext
       if ($azureContext) {
           $azureNeedLogin = [string]::IsNullOrEmpty($azureContext.Account)
           if (-not $azureNeedLogin) {
               Write-Host "Already logged in to Azure as $($azureContext.Account.Id)" -ForegroundColor Green
           }
       }
   } catch {
       if ($_ -like "*Connect-AzAccount to login*") {
           Write-Warning "No Azure account context found. Need to login."
       } else {
           Write-Error "An unexpected error occurred while checking Azure context: $_"
       }
   }


   if ($azureNeedLogin) {
       Write-Host "Logging into Azure..." -ForegroundColor Yellow
       try {
           $azureContext = Connect-AzAccount -UseDeviceAuthentication
           if ($azureContext) {
               Write-Host "Successfully logged in to Azure as $($azureContext.Context.Account.Id)" -ForegroundColor Green
           } else {
               Write-Error "Failed to log into Azure."
           }
       } catch {
           Write-Error "An error occurred while logging into Azure: $_"
       }
   }
}


function Entra-Elevation {
   <#
   .SYNOPSIS
       Activates Entra PIM roles.


   .DESCRIPTION
       Handles the activation of Entra PIM roles through Microsoft Graph.
   #>
   Write-Host "========================================" -ForegroundColor Cyan
   Write-Host "ENTRA PIM Role Activation" -ForegroundColor Cyan
   Write-Host "========================================" -ForegroundColor Cyan


   $graphcontext = Graph-Login


   $currentUser = (Get-MgUser -UserId $graphContext.Account).Id


   # Get all available roles
   $myRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ExpandProperty RoleDefinition -All -Filter "principalId eq '$currentUser'"


   # Bypass role selection if Bypass parameter is used
   if ($Bypass) {
       $myRole = $myRoles | Where-Object { $_.RoleDefinition.DisplayName -eq $Bypass }
       if (-not $myRole) {
           Write-Host "Role '$Bypass' not found or you do not have eligibility for this role." -ForegroundColor Red
           return
       }
   } else {
       # Get User Selection
       $myRole = Get-UserSelection -items $myRoles -prompt "Select role to elevate"
       if (-not $myRole) {
           Write-Host "No role selected or operation cancelled." -ForegroundColor Yellow
           return
       }
   }


   Clear-Host


   $durationInHours = Read-Host "Enter duration in hours: "


   Clear-Host


   # Setup parameters for activation
   $params = @{
       Action = "selfActivate"
       PrincipalId = $myRole.PrincipalId
       RoleDefinitionId = $myRole.RoleDefinitionId
       DirectoryScopeId = $myRole.DirectoryScopeId
       Justification = Read-Host "Enter Justification: "
       ScheduleInfo = @{
           StartDateTime = Get-Date
           Expiration = @{
               Type = "AfterDuration"
               Duration = "PT${durationInHours}H"
           }
       }
   }


   # Activate the role
   try {
       New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
       Write-Host "Successfully activated $($myRole.RoleDefinition.DisplayName) for $($graphContext.Account)" -ForegroundColor Green
   }
   catch {
       Write-Error "Failed To Elevate Role"
   }
}


function Az-Elevation {
   <#
   .SYNOPSIS
       Activates Azure PIM roles.


   .DESCRIPTION
       Handles the activation of Azure PIM roles for specified scopes.
   #>
   Write-Host "========================================" -ForegroundColor Cyan
   Write-Host "AZURE RESOURCES PIM Role Activation" -ForegroundColor Cyan
   Write-Host "========================================" -ForegroundColor Cyan




   $graphContext = Graph-Login
   # Call Az-Login function to log in to azure resources
   Az-Login


   # Determine the scope based on user input or parameter
   if (-not $ScopeType) {
       $scopes = @(
           [PSCustomObject]@{Name = "Management Groups"},
           [PSCustomObject]@{Name = "Subscriptions"},
           [PSCustomObject]@{Name = "Resource Groups"}
       )


       $scopeType = Get-UserSelection -items $scopes -prompt "Select the scope level for the elevation: "
       $ScopeType = $scopeType.Name
   }


   # Determine the scope name based on user input or parameter
   if (-not $ScopeName) {
       if ($ScopeType -eq "Management Groups") {
           $managementGroups = Get-AzManagementGroup | Select-Object DisplayName, Id
           $selectedGroup = Get-UserSelection -items $managementGroups -prompt "Available Management Groups"
           if ($selectedGroup -eq $null) {
               Write-Host "No management group selected or operation cancelled." -ForegroundColor Yellow
               return
           }
           $ScopeName = $selectedGroup.DisplayName
           $scope = $selectedGroup.Id
       }
       elseif ($ScopeType -eq "Subscriptions") {
           $subscriptions = Get-AzSubscription | Select-Object Name, Id
           $selectedSubscription = Get-UserSelection -items $subscriptions -prompt "Available Subscriptions"
           if ($selectedSubscription -eq $null) {
               Write-Host "No subscription selected or operation cancelled." -ForegroundColor Yellow
               return
           }
           $ScopeName = $selectedSubscription.Name
           $scope = "/subscriptions/$($selectedSubscription.Id)"
       }
       elseif ($ScopeType -eq "Resource Groups") {
           $subscriptions = Get-AzSubscription | Select-Object Name, Id
           $selectedSubscription = Get-UserSelection -items $subscriptions -prompt "Available Subscriptions"
           if ($selectedSubscription -eq $null) {
               Write-Host "No subscription selected or operation cancelled." -ForegroundColor Yellow
               return
           }
           Set-AzContext -Subscription $selectedSubscription.Name
           $resourceGroups = Get-AzResourceGroup | Select-Object ResourceGroupName, Id
           $selectedResourceGroup = Get-UserSelection -items $resourceGroups -prompt "Available Resource Groups"
           if ($selectedResourceGroup -eq $null) {
               Write-Host "No resource group selected or operation cancelled." -ForegroundColor Yellow
               return
           }
           $ScopeName = $selectedResourceGroup.ResourceGroupName
           $scope = "/subscriptions/$($selectedSubscription.Id)/resourceGroups/$($ScopeName)"
       }
       else {
           Write-Host "Invalid scope type. Exiting script." -ForegroundColor Red
           return
       }
   } else {
       # Set the scope based on provided ScopeName
       if ($ScopeType -eq "Management Groups") {
           $selectedGroup = Get-AzManagementGroup | Where-Object { $_.DisplayName -eq $ScopeName }
           if ($selectedGroup -eq $null) {
               Write-Host "Management Group '$ScopeName' not found." -ForegroundColor Red
               return
           }
           $scope = $selectedGroup.Id
       }
       elseif ($ScopeType -eq "Subscriptions") {
           $selectedSubscription = Get-AzSubscription | Where-Object { $_.Name -eq $ScopeName }
           if ($selectedSubscription -eq $null) {
               Write-Host "Subscription '$ScopeName' not found." -ForegroundColor Red
               return
           }
           $scope = "/subscriptions/$($selectedSubscription.Id)"
       }
       elseif ($ScopeType -eq "Resource Groups") {
           $selectedSubscription = Get-AzSubscription | Select-Object Name, Id
           $resourceGroups = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -eq $ScopeName }
           if ($resourceGroups -eq $null) {
               Write-Host "Resource Group '$ScopeName' not found." -ForegroundColor Red
               return
           }
           $scope = "/subscriptions/$($selectedSubscription.Id)/resourceGroups/$($ScopeName)"
       }
   }


   Write-Host "Scope set to $ScopeType level: $ScopeName" -ForegroundColor Green


   # Get all group memberships
   $groups = Get-MgUserMemberOf -UserId $graphContext.Account
   # Query Azure for all available eligible PIM roles
   Write-Host "Querying Azure for available eligible PIM roles..."
   $eligibleRoles = Get-AzRoleEligibilityScheduleInstance -Scope $scope | Sort-Object -Property RoleDefinitionDisplayName -Descending | Where-Object { $_.Scope -eq $scope -and $_.PrincipalId -in $groups.Id }


   # Check if any roles were found
   if ($eligibleRoles -eq $null -or $eligibleRoles.Count -eq 0) {
       Write-Host "No eligible PIM roles found for the specified scope." -ForegroundColor Red
       return
   }


   # Bypass role selection if Bypass parameter is used
   if ($Bypass) {
       $selectedRole = $eligibleRoles | Where-Object { $_.RoleDefinitionDisplayName -eq $Bypass }
       if (-not $selectedRole) {
           Write-Host "Role '$Bypass' not found or you do not have eligibility for this role." -ForegroundColor Red
           return
       }
   } else {
       # Get user selection
       $selectedRole = Get-UserSelection -items $eligibleRoles -prompt "Available Eligible Roles"
       if (-not $selectedRole) {
           Write-Host "No role selected or operation cancelled." -ForegroundColor Yellow
           return
       }
   }


   # Extract the role name from the selected role
   $role = $selectedRole.RoleDefinitionDisplayName
   Write-Host "You have selected the role: $($role)`n" -ForegroundColor Green


   # Set Params
   $currentUser = (Get-MgUser -UserId $graphContext.Account).Id
   $guid = New-Guid
   $role = $selectedRole.RoleDefinitionId


   Clear-Host
   $Justification = Read-Host "Enter Justification for elevation: "


   Clear-Host


   $durationInHours = Read-Host "Enter duration in hours: "


   # Activate the selected PIM role
   Write-Host "Activating PIM role: $role... `n`n`n"
   $activationResult = New-AzRoleAssignmentScheduleRequest -Name $guid -Scope $scope -RoleDefinitionId $role -PrincipalId $currentUser -Justification $Justification -RequestType 'SelfActivate' -ExpirationDuration "PT$($durationInHours)H" -ExpirationType 'AfterDuration'


   if ($activationResult) {
       Write-Host "PIM role activated successfully." -ForegroundColor Green
       Write-Host "========================================" -ForegroundColor Cyan
       Write-Host "Activation Completed Successfully" -ForegroundColor Green
       Write-Host "========================================" -ForegroundColor Cyan
   } else {
       Write-Host "Failed to activate PIM role." -ForegroundColor Red
   }
}


function main {
   # Check if the Help parameter is specified
  
   if ($Help) {
   Show-Help
   return
   }
 
   Install-RequiredModules
   Graph-Login


   # Determine role type based on parameter or prompt
   if (-not $RoleType) {
       $roleTypes = @(
           [PSCustomObject]@{Name = "Entra Roles"},
           [PSCustomObject]@{Name = "Azure Resources"}
       )


       $selectedRoleType = Get-UserSelection -items $roleTypes -prompt "Select the type of role to activate"
       $RoleType = $selectedRoleType.Name
   }


   # Execute the appropriate elevation function
   if ($RoleType -eq "Azure Resources") {
       Az-Elevation
   } else {
       Entra-Elevation
   }
}


main



