# cveBuster CCF Connector - Deployment Guide

## 📋 Overview

This ARM template deploys a complete Codeless Connector Framework (CCF) data connector for Microsoft Sentinel that pulls vulnerability data from your cveBuster Flask API.

## 🏗️ What Gets Created

The template deploys:

1. **Custom Log Analytics Table**: `cveBusterVulnerabilities_CL`
   - Stores all vulnerability scan data with proper schema
   
2. **Data Collection Rule (DCR)**
   - Defines how data is ingested and transformed
   - Stream name: `Custom-cveBusterInput`
   
3. **Data Connector UI Definition**
   - Appears in Microsoft Sentinel data connector gallery
   - User-friendly configuration interface
   
4. **RestApiPoller Connection**
   - Polls your Flask API every 5 minutes
   - API Key authentication
   - Automatic retry and error handling

---

## 📝 Prerequisites

### 1. Microsoft Sentinel Workspace
You need:
- Active Microsoft Sentinel workspace
- Contributor permissions on the workspace
- The workspace name and resource group

### 2. Data Collection Endpoint (DCE)
Create a DCE if you don't have one:

```bash
# Via Azure Portal
# Navigate to: Monitor > Data Collection Endpoints > Create
# Name: <workspace-name>-dce
# Region: Same as your Sentinel workspace

# Or via Azure CLI
az monitor data-collection endpoint create \
  --name "<workspace-name>-dce" \
  --resource-group "<resource-group-name>" \
  --location "<location>" \
  --public-network-access Enabled
```

### 3. cveBuster API
Ensure your API is running and accessible:
- URL: `http://20.84.144.179:5000/api/vulnerabilities`
- API Key: `cvebuster-demo-key-12345`
- Test it: 
  ```powershell
  Invoke-RestMethod -Uri "http://20.84.144.179:5000/api/vulnerabilities" -Headers @{Authorization="cvebuster-demo-key-12345"}
  ```

---

## 🚀 Deployment Steps

### Option 1: Deploy via Azure Portal (Recommended for Testing)

1. **Navigate to Custom Deployment**
   - Go to: https://portal.azure.com/#create/Microsoft.Template
   - Or search for "Deploy a custom template"

2. **Load the Template**
   - Click "Build your own template in the editor"
   - Copy and paste the contents of `cveBuster-CCF-ARM-Template.json`
   - Click "Save"

3. **Configure Parameters**
   - **Subscription**: Select your Azure subscription
   - **Resource Group**: Select the resource group containing your Sentinel workspace
   - **Workspace**: Enter your Log Analytics workspace name (not the full resource ID, just the name)
   - **Workspace Location**: Enter the region (e.g., `eastus`, `westeurope`)

4. **Review and Deploy**
   - Click "Review + create"
   - Review the resources that will be created
   - Click "Create"

5. **Deployment Time**: ~5-10 minutes

### Option 2: Deploy via Azure CLI

```bash
# Set variables
RESOURCE_GROUP="<your-resource-group>"
WORKSPACE_NAME="<your-workspace-name>"
WORKSPACE_LOCATION="<region>"  # e.g., eastus

# Deploy the template
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file cveBuster-CCF-ARM-Template.json \
  --parameters workspace=$WORKSPACE_NAME \
               workspace-location=$WORKSPACE_LOCATION
```

### Option 3: Deploy via PowerShell

```powershell
$resourceGroup = "<your-resource-group>"
$workspaceName = "<your-workspace-name>"
$workspaceLocation = "<region>"

New-AzResourceGroupDeployment `
  -ResourceGroupName $resourceGroup `
  -TemplateFile .\cveBuster-CCF-ARM-Template.json `
  -workspace $workspaceName `
  -workspace-location $workspaceLocation
```

---

## ⚙️ Configure the Data Connector

After deployment completes:

1. **Navigate to Microsoft Sentinel**
   - Go to your Sentinel workspace
   - Click "Data connectors" in the left menu

2. **Find cveBuster Connector**
   - Search for "cveBuster" in the data connectors gallery
   - Click on "cveBuster Vulnerability Scanner"
   - Click "Open connector page"

3. **Configure Connection**
   - **API Endpoint URL**: `http://20.84.144.179:5000/api/vulnerabilities`
   - **API Key**: `cvebuster-demo-key-12345`
   - Click "Connect"

4. **Verify Connection**
   - Status should change to "Connected"
   - Wait ~5-10 minutes for initial data ingestion

---

## 🔍 Verify Data Ingestion

### Check in Log Analytics

Run this KQL query in your Sentinel workspace:

```kql
// Check for cveBuster data
cveBusterVulnerabilities_CL
| take 10

// View recent vulnerabilities
cveBusterVulnerabilities_CL
| sort by TimeGenerated desc
| take 20

// Count by severity
cveBusterVulnerabilities_CL
| summarize Count = count() by Severity
| order by Count desc

// Critical vulnerabilities with exploits
cveBusterVulnerabilities_CL
| where Severity == "Critical" and ExploitAvailable == true
| project TimeGenerated, MachineName, VulnId, VulnTitle, CVSS
| sort by CVSS desc
```

### Monitor Connector Health

1. In the connector page, check:
   - **Status**: Should be "Connected"
   - **Data received**: Should show recent timestamp
   - **Logs received graph**: Should show data points

2. Check DCR status:
   ```bash
   az monitor data-collection rule show \
     --name "cveBusterDCR" \
     --resource-group "<resource-group>"
   ```

---

## 🧪 Testing Different Poller Settings

The connector polls every **5 minutes** by default. To test different settings:

### 1. Change Polling Frequency

Edit the connection in the ARM template and redeploy, or use the API:

```json
"request": {
  "queryWindowInMin": 1,  // Change from 5 to 1 minute for faster polling
  ...
}
```

### 2. Modify Rate Limiting

```json
"request": {
  "rateLimitQPS": 20,  // Increase from 10 to 20 queries per second
  ...
}
```

### 3. Adjust Retry Behavior

```json
"request": {
  "retryCount": 5,  // Increase from 3 to 5 retries
  "timeoutInSeconds": 120,  // Increase timeout
  ...
}
```

---

## 🔧 Troubleshooting

### No Data Appearing

1. **Check API is accessible from Azure**
   ```bash
   # Make sure your VM firewall allows Azure IPs
   # Consider using Azure Private Link or VPN for production
   ```

2. **Verify DCE exists**
   ```bash
   az monitor data-collection endpoint list \
     --resource-group "<resource-group>"
   ```

3. **Check connector logs**
   - Navigate to: Sentinel > Data connectors > cveBuster
   - Look for error messages in the status

4. **Verify API response format**
   - Ensure your API returns data in `$.data` array
   - The connector expects: `{"data": [...], "timestamp": "...", "count": 10}`

### Connection Failing

1. **Check API Key**
   - Ensure the API key matches exactly: `cvebuster-demo-key-12345`
   - Check for extra spaces or characters

2. **Test API manually**
   ```powershell
   Invoke-RestMethod -Uri "http://20.84.144.179:5000/api/vulnerabilities" `
     -Headers @{Authorization="cvebuster-demo-key-12345"}
   ```

3. **Network connectivity**
   - Ensure Azure can reach your VM IP (20.84.144.179)
   - Check NSG/firewall rules on your VM

### Data Format Issues

If data appears malformed:

1. **Check the DCR transformation**
   - The KQL transform is: `source | extend TimeGenerated = now()`
   - Modify if needed for your data structure

2. **Verify field mappings**
   - Ensure all fields in your JSON match the table schema
   - Boolean fields: `true`/`false` (not strings)
   - Datetime fields: ISO 8601 format

---

## 📊 Sample Queries

Once data is flowing, try these queries:

```kql
// Vulnerability trends over time
cveBusterVulnerabilities_CL
| summarize Count = count() by bin(TimeGenerated, 1h), Severity
| render timechart

// Top vulnerable machines
cveBusterVulnerabilities_CL
| summarize VulnCount = count() by MachineName, AssetCriticality
| order by VulnCount desc
| take 10

// Exploited in the wild
cveBusterVulnerabilities_CL
| where ExploitedInWild == true
| project MachineName, VulnId, VulnTitle, Severity, CVSS, LastScanTime
| order by CVSS desc

// Patch compliance
cveBusterVulnerabilities_CL
| summarize 
    Total = count(),
    WithPatch = countif(PatchAvailable == true),
    WithoutPatch = countif(PatchAvailable == false)
| extend PatchComplianceRate = (WithPatch * 100.0) / Total
```

---

## 🔄 Refreshing Test Data

To generate fresh data with new timestamps:

1. **On your VM** (20.84.144.179):
   ```bash
   cd ~/cveBusterCCF/cveBusterCCF/cveBusterCCF/cveBusterCCF
   python3 generate_data.py
   ```

2. **Wait for next poll cycle** (~5 minutes)

3. **Verify in Sentinel**:
   ```kql
   cveBusterVulnerabilities_CL
   | where TimeGenerated > ago(10m)
   | count
   ```

---

## 🗑️ Clean Up (Optional)

To remove the connector:

```bash
# Delete the data connector
az resource delete \
  --resource-group "<resource-group>" \
  --name "cveBusterDataConnector" \
  --namespace "Microsoft.SecurityInsights" \
  --resource-type "dataConnectors" \
  --parent "workspaces/<workspace-name>/providers/Microsoft.SecurityInsights"

# Delete the DCR
az monitor data-collection rule delete \
  --name "cveBusterDCR" \
  --resource-group "<resource-group>"

# Optionally delete the custom table (data will be retained for retention period)
```

---

## 📚 Next Steps

1. **Create Analytics Rules** - Detect critical vulnerabilities
2. **Build Workbooks** - Visualize vulnerability trends
3. **Set up Automation** - Auto-remediate with Logic Apps
4. **Test Advanced Features**:
   - Pagination (if API supports it)
   - OAuth2 authentication
   - Complex KQL transformations in DCR

---

## 🆘 Support

For issues or questions:
- Review Microsoft Sentinel CCF documentation
- Check Azure Monitor DCR logs
- Test API connectivity from Azure Cloud Shell

---

**Happy Testing!** 🚀
