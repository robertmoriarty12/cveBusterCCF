<#
.SYNOPSIS
    Deploy cveBuster CCF Connector to Microsoft Sentinel

.DESCRIPTION
    This script deploys all necessary components for the cveBuster Codeless Connector Framework (CCF):
    - Data Collection Endpoint (DCE)
    - Custom Log Analytics Table
    - Data Collection Rule (DCR)
    - Data Connector Poller

.NOTES
    Author: robertmoriarty12
    Date: 2025-11-01
    Version: 1.0
#>

# ============================================================================
# MODULE REQUIREMENTS - Auto-import required modules
# ============================================================================
$requiredModules = @('Az.Accounts', 'Az.OperationalInsights', 'Az.Monitor', 'Az.Resources')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Host "❌ Module '$module' is not installed. Please run: Install-Module -Name $module -Scope CurrentUser" -ForegroundColor Red
        exit 1
    }
    Import-Module $module -ErrorAction Stop
}

# ============================================================================
# CONFIGURATION SECTION - UPDATE THESE VALUES AS NEEDED
# ============================================================================

# Azure Subscription & Resource Group
$SubscriptionId = "7fd8d7c4-f9bd-43cf-908d-a6b675789480"
$ResourceGroupName = "rg-mssentinel-lab1"
$Location = "eastus"  # East US

# Microsoft Sentinel Workspace
$WorkspaceName = "sentinel-mt425li7vpf6w"
$WorkspaceId = "80526fa6-c8b9-4aa6-9c99-b429af65ec89"

# cveBuster API Configuration
$ApiEndpoint = "http://20.84.144.179:5000/api/vulnerabilities"
$ApiKey = "cvebuster-demo-key-12345"

# Component Names (customize if needed)
$DceName = "$WorkspaceName-dce"
$DcrName = "cveBusterVulnerabilitiesDCR"
$TableName = "cveBusterVulnerabilities_CL"
$PollerName = "cveBusterPoller_vulnerabilities"
$StreamName = "Custom-cveBusterVulnerabilities_API"

# Script Behavior
$DeployDCE = $true          # Set to $false if you already have a DCE
$SkipConfirmation = $false  # Set to $true to skip confirmation prompts

# ============================================================================
# DO NOT MODIFY BELOW THIS LINE UNLESS YOU KNOW WHAT YOU'RE DOING
# ============================================================================

$ErrorActionPreference = "Stop"

# Helper function for colored output
function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    switch ($Type) {
        "Success" { Write-Host "✅ $Message" -ForegroundColor Green }
        "Error"   { Write-Host "❌ $Message" -ForegroundColor Red }
        "Warning" { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        "Info"    { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
        "Step"    { Write-Host "`n🔹 $Message" -ForegroundColor Magenta }
        default   { Write-Host $Message }
    }
}

# Banner
Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   cveBuster CCF Connector - Deployment Script" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Display configuration
Write-Status "Deployment Configuration:" "Info"
Write-Host "  Subscription ID   : $SubscriptionId" -ForegroundColor Gray
Write-Host "  Resource Group    : $ResourceGroupName" -ForegroundColor Gray
Write-Host "  Location          : $Location" -ForegroundColor Gray
Write-Host "  Workspace Name    : $WorkspaceName" -ForegroundColor Gray
Write-Host "  API Endpoint      : $ApiEndpoint" -ForegroundColor Gray
Write-Host ""

# Confirmation prompt
if (-not $SkipConfirmation) {
    $confirm = Read-Host "Do you want to proceed with deployment? (Y/N)"
    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
        Write-Status "Deployment cancelled by user." "Warning"
        exit 0
    }
}

try {
    # ============================================================================
    # Step 1: Connect to Azure
    # ============================================================================
    Write-Status "Connecting to Azure..." "Step"
    
    $context = Get-AzContext
    if (-not $context) {
        Write-Status "No Azure context found. Please sign in..." "Warning"
        Connect-AzAccount
        $context = Get-AzContext
    }
    
    # Set subscription context
    if ($context.Subscription.Id -ne $SubscriptionId) {
        Write-Status "Switching to subscription: $SubscriptionId" "Info"
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }
    
    Write-Status "Connected to Azure (Subscription: $($context.Subscription.Name))" "Success"

    # ============================================================================
    # Step 2: Verify Workspace Exists
    # ============================================================================
    Write-Status "Verifying Log Analytics Workspace..." "Step"
    
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction SilentlyContinue
    
    if (-not $workspace) {
        throw "Workspace '$WorkspaceName' not found in resource group '$ResourceGroupName'"
    }
    
    $WorkspaceResourceId = $workspace.ResourceId
    Write-Status "Workspace verified: $WorkspaceName" "Success"

    # ============================================================================
    # Step 3: Create Data Collection Endpoint (DCE)
    # ============================================================================
    if ($DeployDCE) {
        Write-Status "Creating Data Collection Endpoint..." "Step"
        
        # Check if DCE already exists
        $dce = Get-AzDataCollectionEndpoint -ResourceGroupName $ResourceGroupName -Name $DceName -ErrorAction SilentlyContinue
        
        if ($dce) {
            Write-Status "DCE '$DceName' already exists. Skipping creation." "Warning"
            $DceResourceId = $dce.Id
            Write-Host "  Endpoint URI: $($dce.LogIngestionEndpoint)" -ForegroundColor Gray
        } else {
            $dceParams = @{
                Name = $DceName
                ResourceGroupName = $ResourceGroupName
                Location = $Location
                NetworkAclsPublicNetworkAccess = "Enabled"
            }
            
            $dce = New-AzDataCollectionEndpoint @dceParams
            $DceResourceId = $dce.Id
            Write-Status "DCE created: $DceName" "Success"
            Write-Host "  Endpoint URI: $($dce.LogIngestionEndpoint)" -ForegroundColor Gray
        }
    } else {
        Write-Status "Skipping DCE creation (DeployDCE = false)" "Warning"
        # Attempt to find existing DCE
        $dce = Get-AzDataCollectionEndpoint -ResourceGroupName $ResourceGroupName -Name $DceName -ErrorAction SilentlyContinue
        if ($dce) {
            $DceResourceId = $dce.Id
            Write-Status "Using existing DCE: $DceName" "Info"
        } else {
            throw "DCE '$DceName' not found and DeployDCE is set to false. Please create a DCE or set DeployDCE = true"
        }
    }

    # ============================================================================
    # Step 4: Create Custom Log Analytics Table
    # ============================================================================
    Write-Status "Creating Custom Log Analytics Table..." "Step"
    
    # Load table schema from Table.json
    $tableJsonPath = Join-Path $PSScriptRoot "Table.json"
    if (-not (Test-Path $tableJsonPath)) {
        throw "Table.json not found at: $tableJsonPath"
    }
    
    $tableSchema = Get-Content $tableJsonPath -Raw | ConvertFrom-Json
    
    # Build REST API call to create table
    $tableUri = "$WorkspaceResourceId/tables/$($TableName)?api-version=2022-10-01"
    
    $tableBody = @{
        properties = $tableSchema.properties
    } | ConvertTo-Json -Depth 10
    
    try {
        # Use Invoke-AzRestMethod which handles authentication automatically
        $response = Invoke-AzRestMethod -Path $tableUri -Method PUT -Payload $tableBody
        
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
            Write-Status "Table created: $TableName" "Success"
        } elseif ($response.StatusCode -eq 409) {
            Write-Status "Table '$TableName' already exists. Continuing..." "Warning"
        } else {
            throw "Failed to create table. Status Code: $($response.StatusCode), Content: $($response.Content)"
        }
    } catch {
        if ($_.Exception.Message -like "*409*" -or $_.Exception.Message -like "*already exists*") {
            Write-Status "Table '$TableName' already exists. Continuing..." "Warning"
        } else {
            throw "Failed to create table: $($_.Exception.Message)"
        }
    }

    # ============================================================================
    # Step 5: Create Data Collection Rule (DCR)
    # ============================================================================
    Write-Status "Creating Data Collection Rule..." "Step"
    
    # Load DCR from DCR.json
    $dcrJsonPath = Join-Path $PSScriptRoot "DCR.json"
    if (-not (Test-Path $dcrJsonPath)) {
        throw "DCR.json not found at: $dcrJsonPath"
    }
    
    $dcrTemplate = Get-Content $dcrJsonPath -Raw
    
    # Replace placeholders
    $dcrTemplate = $dcrTemplate -replace '{{location}}', $Location
    $dcrTemplate = $dcrTemplate -replace '{{dataCollectionEndpointId}}', $DceResourceId
    $dcrTemplate = $dcrTemplate -replace '{{workspaceResourceId}}', $WorkspaceResourceId
    
    $dcrConfig = $dcrTemplate | ConvertFrom-Json
    
    # Build REST API call to create DCR
    $dcrUri = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Insights/dataCollectionRules/$($DcrName)?api-version=2021-09-01-preview"
    
    $dcrBody = @{
        location = $Location
        properties = $dcrConfig.properties
    } | ConvertTo-Json -Depth 20
    
    try {
        $response = Invoke-AzRestMethod -Path $dcrUri -Method PUT -Payload $dcrBody
        
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
            $dcrResponse = $response.Content | ConvertFrom-Json
            $DcrImmutableId = $dcrResponse.properties.immutableId
            Write-Status "DCR created: $DcrName" "Success"
            Write-Host "  Immutable ID: $DcrImmutableId" -ForegroundColor Gray
        } else {
            throw "Failed to create DCR. Status Code: $($response.StatusCode), Content: $($response.Content)"
        }
    } catch {
        throw "Failed to create DCR: $($_.Exception.Message)"
    }

    # ============================================================================
    # Step 5.5: Create Connector Definition
    # ============================================================================
    Write-Status "Creating Connector Definition..." "Step"
    
    $connectorDefName = "cveBuster"
    # Use stable API version
    $connectorDefUri = "$WorkspaceResourceId/providers/Microsoft.SecurityInsights/dataConnectorDefinitions/$($connectorDefName)?api-version=2024-01-01-preview"
    
    $connectorDefBody = @{
        kind = "Customizable"
        properties = @{
            connectorUiConfig = @{
                title = "cveBuster (via REST API)"
                publisher = "cveBuster"
                descriptionMarkdown = "This connector ingests cveBuster vulnerability data via REST API polling."
                graphQueries = @(
                    @{
                        metricName = "Total data received"
                        legend = "cveBuster"
                        baseQuery = $TableName
                    }
                )
                dataTypes = @(
                    @{
                        name = $TableName
                        lastDataReceivedQuery = "$TableName`n| summarize Time = max(TimeGenerated)`n| where isnotempty(Time)"
                    }
                )
                connectivityCriteria = @(
                    @{
                        type = "HasDataConnectors"
                        value = $null
                    }
                )
                availability = @{
                    status = 1
                }
                permissions = @{
                    resourceProvider = @(
                        @{
                            provider = "Microsoft.OperationalInsights/workspaces"
                            permissionsDisplayText = "read and write permissions are required."
                            providerDisplayName = "Workspace"
                            scope = "Workspace"
                            requiredPermissions = @{
                                read = $true
                                write = $true
                            }
                        }
                    )
                }
                instructionSteps = @(
                    @{
                        title = "Connect to cveBuster API"
                        description = "Enter your API details"
                    }
                )
            }
        }
    } | ConvertTo-Json -Depth 20
    
    try {
        $response = Invoke-AzRestMethod -Path $connectorDefUri -Method PUT -Payload $connectorDefBody
        
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
            Write-Status "Connector Definition created: $connectorDefName" "Success"
        } else {
            Write-Status "Connector Definition returned HTTP $($response.StatusCode)" "Warning"
            Write-Host "  Error: $($response.Content)" -ForegroundColor Yellow
            throw "Cannot proceed without connector definition"
        }
    } catch {
        throw "Failed to create connector definition: $($_.Exception.Message)"
    }

    # ============================================================================
    # Step 6: Create Data Connector Poller
    # ============================================================================
    Write-Status "Creating Data Connector Poller..." "Step"
    
    # Load Poller from PollerConfig.json
    $pollerJsonPath = Join-Path $PSScriptRoot "PollerConfig.json"
    if (-not (Test-Path $pollerJsonPath)) {
        throw "PollerConfig.json not found at: $pollerJsonPath"
    }
    
    $pollerArray = Get-Content $pollerJsonPath -Raw | ConvertFrom-Json
    $pollerConfig = $pollerArray[0]  # Get first poller from array
    
    # Build the poller properties (replace ARM template placeholders with actual values)
    $pollerProperties = $pollerConfig.properties | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    
    # Keep a generic connectorDefinitionName for testing
    # In production, this would reference a full solution deployed via Content Hub
    if (-not $pollerProperties.connectorDefinitionName) {
        $pollerProperties | Add-Member -NotePropertyName "connectorDefinitionName" -NotePropertyValue "GenericRestApiPoller" -Force
    }
    
    # Replace parameters with actual values
    $pollerProperties.dcrConfig.dataCollectionEndpoint = $dce.LogIngestionEndpoint
    $pollerProperties.dcrConfig.dataCollectionRuleImmutableId = $DcrImmutableId
    $pollerProperties.auth.ApiKey = $ApiKey
    $pollerProperties.request.apiEndpoint = $ApiEndpoint
    
    # Debug: Show what we're sending
    Write-Host "  Poller configuration:" -ForegroundColor Gray
    Write-Host "    Connector Definition: $($pollerProperties.connectorDefinitionName)" -ForegroundColor Gray
    Write-Host "    Stream: $($pollerProperties.dcrConfig.streamName)" -ForegroundColor Gray
    Write-Host "    Endpoint: $($pollerProperties.request.apiEndpoint)" -ForegroundColor Gray
    
    # Build REST API call to create poller
    $pollerUri = "$WorkspaceResourceId/providers/Microsoft.SecurityInsights/dataConnectors/$($PollerName)?api-version=2023-02-01-preview"
    
    $pollerBody = @{
        kind = $pollerConfig.kind
        properties = $pollerProperties
    } | ConvertTo-Json -Depth 20
    
    try {
        $response = Invoke-AzRestMethod -Path $pollerUri -Method PUT -Payload $pollerBody
        
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
            Write-Status "Data Connector Poller created: $PollerName" "Success"
        } else {
            throw "Failed to create poller. Status Code: $($response.StatusCode), Content: $($response.Content)"
        }
    } catch {
        throw "Failed to create poller: $($_.Exception.Message)"
    }

    # ============================================================================
    # Deployment Summary
    # ============================================================================
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "   ✅ Deployment Completed Successfully!" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Deployed Components:" -ForegroundColor Cyan
    Write-Host "  ✓ Data Collection Endpoint  : $DceName" -ForegroundColor Gray
    Write-Host "  ✓ Custom Table              : $TableName" -ForegroundColor Gray
    Write-Host "  ✓ Data Collection Rule      : $DcrName" -ForegroundColor Gray
    Write-Host "  ✓ Data Connector Poller     : $PollerName" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Navigate to Microsoft Sentinel > Data connectors" -ForegroundColor Gray
    Write-Host "  2. Wait 5-10 minutes for first data ingestion" -ForegroundColor Gray
    Write-Host "  3. Query data: $TableName | take 10" -ForegroundColor Gray
    Write-Host ""
    Write-Host "API Configuration:" -ForegroundColor Cyan
    Write-Host "  Endpoint: $ApiEndpoint" -ForegroundColor Gray
    Write-Host "  Polling Interval: 5 minutes" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Status "Deployment failed: $($_.Exception.Message)" "Error"
    Write-Host ""
    Write-Host "Error Details:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    Write-Host ""
    exit 1
}
