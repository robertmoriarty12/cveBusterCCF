# cveBuster CCF Connector for Microsoft Sentinel

A complete implementation of a **Codeless Connector Framework (CCF)** data connector that ingests vulnerability data from a custom REST API into Microsoft Sentinel using REST API polling.

## 🎯 Project Overview

This project demonstrates how to build a custom CCF data connector for Microsoft Sentinel without publishing a full solution to the Azure Marketplace. Perfect for testing CCF capabilities and creating custom integrations.

**What it does:**
- Polls a custom Flask API every 5 minutes for vulnerability scan data
- Transforms and ingests data into a custom Sentinel table
- Uses Data Collection Rules (DCR) for parsing and transformation
- Implements API key authentication

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│  Flask API (Ubuntu VM: 20.84.144.179:5000)         │
│  ├── app.py              (REST API server)          │
│  ├── generate_data.py    (Data generator)           │
│  └── cvebuster_data.json (Sample data)              │
└─────────────────────────────────────────────────────┘
                        │
                        │ HTTP GET /api/vulnerabilities
                        │ Every 5 minutes
                        │ API Key: Authorization header
                        ▼
┌─────────────────────────────────────────────────────┐
│  CCF Data Connector (Microsoft Sentinel)            │
│  ├── Data Collection Endpoint (DCE)                 │
│  ├── Data Collection Rule (DCR)                     │
│  │   └── Stream: Custom-cveBusterVulnerabilities_API│
│  ├── RestApiPoller                                  │
│  │   ├── Polls API endpoint                         │
│  │   ├── Parses JSON response ($.data path)         │
│  │   └── Sends to DCR for transformation            │
│  └── Connector Definition                           │
└─────────────────────────────────────────────────────┘
                        │
                        │ Transformed logs
                        ▼
┌─────────────────────────────────────────────────────┐
│  Log Analytics / Microsoft Sentinel                 │
│  └── Table: cveBusterVulnerabilities_CL             │
│      ├── TimeGenerated                              │
│      ├── MachineName, HostId, IPAddress             │
│      ├── VulnId, VulnTitle, Severity                │
│      ├── ExploitAvailable, PatchAvailable           │
│      └── ... (19 vulnerability fields)              │
└─────────────────────────────────────────────────────┘
```

## 📁 Project Structure

### **Core Files (In Use)**

| File | Purpose |
|------|---------|
| `app.py` | Flask REST API server serving vulnerability data |
| `generate_data.py` | Generates randomized vulnerability scan data |
| `cvebuster_data.json` | Sample vulnerability data (10 records) |
| `requirements.txt` | Python dependencies for Flask API |
| `DCR.json` | Data Collection Rule with stream definition & KQL transformation |
| `PollerConfig.json` | REST API poller configuration (auth, endpoint, polling interval) |
| `Table.json` | Log Analytics custom table schema (20 columns) |
| `Deploy-cveBusterCCF.ps1` | **PowerShell deployment script** - deploys all Azure components |

### **Legacy Files (Not Used)**
- `cveBuster-CCF-ARM-Template.json` - Old monolithic ARM template approach (replaced by PowerShell script)
- `deploy-poller-arm.json` - Experimental ARM template (not needed)
- `DEPLOYMENT_GUIDE.md` - Outdated documentation for ARM approach

## 🚀 Quick Start

### **Prerequisites**

1. **Azure Requirements:**
   - Microsoft Sentinel workspace
   - Contributor permissions on the workspace
   - Azure PowerShell modules: `Az.Accounts`, `Az.OperationalInsights`, `Az.Monitor`, `Az.Resources`

2. **Flask API Setup:**
   - Ubuntu VM with Python 3.x
   - Flask 3.0.0 installed
   - API accessible via HTTP

### **Step 1: Deploy the Flask API**

```bash
# On Ubuntu VM
cd /path/to/project

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Generate sample data
python3 generate_data.py

# Run Flask API
python3 app.py
# API will be available at http://<YOUR_VM_IP>:5000
```

### **Step 2: Configure Deployment**

Edit `Deploy-cveBusterCCF.ps1` and update the variables at the top:

```powershell
# Azure Subscription & Resource Group
$SubscriptionId = "your-subscription-id"
$ResourceGroupName = "your-resource-group"
$Location = "eastus"

# Microsoft Sentinel Workspace
$WorkspaceName = "your-workspace-name"
$WorkspaceId = "your-workspace-id"

# cveBuster API Configuration
$ApiEndpoint = "http://YOUR_VM_IP:5000/api/vulnerabilities"
$ApiKey = "cvebuster-demo-key-12345"
```

### **Step 3: Deploy to Azure**

```powershell
# Connect to Azure
Connect-AzAccount

# Run deployment script
.\Deploy-cveBusterCCF.ps1
```

The script will deploy:
1. ✅ Data Collection Endpoint (DCE)
2. ✅ Custom Log Analytics Table
3. ✅ Data Collection Rule (DCR)
4. ✅ Connector Definition
5. ✅ RestApiPoller

### **Step 4: Verify Data Ingestion**

Wait 5-10 minutes, then query in Sentinel:

```kql
cveBusterVulnerabilities_CL
| take 10
```

## 📊 Data Schema

The connector ingests 19 vulnerability fields:

| Field | Type | Description |
|-------|------|-------------|
| `TimeGenerated` | datetime | Log ingestion timestamp |
| `MachineName` | string | Hostname of scanned machine |
| `HostId` | string | Unique host identifier |
| `IPAddress` | string | IP address |
| `OSFamily` | string | Operating system |
| `Application` | string | Vulnerable application |
| `AppFilePath` | string | Application file path |
| `VulnId` | string | CVE identifier |
| `VulnTitle` | string | Vulnerability description |
| `Severity` | string | Critical/High/Medium/Low |
| `CVSS` | real | CVSS score (0-10) |
| `ExploitAvailable` | boolean | Public exploit exists |
| `ExploitedInWild` | boolean | Active exploitation detected |
| `PatchAvailable` | boolean | Patch available |
| `FirstSeen` | datetime | First detection timestamp |
| `LastSeen` | datetime | Last detection timestamp |
| `LastScanTime` | datetime | Most recent scan time |
| `AssetCriticality` | string | Business criticality |
| `BusinessOwner` | string | Asset owner |
| `Source` | string | Data source (cveBuster) |

## 🔧 Configuration Details

### **API Polling Configuration**

From `PollerConfig.json`:
- **Polling Interval:** 5 minutes
- **Authentication:** API Key (Bearer token in Authorization header)
- **HTTP Method:** GET
- **Response Path:** `$.data` (extracts array from JSON response)
- **Rate Limit:** 10 QPS
- **Retry Count:** 3
- **Timeout:** 60 seconds

### **Data Collection Rule (DCR)**

From `DCR.json`:
- **Stream Name:** `Custom-cveBusterVulnerabilities_API`
- **Output Stream:** `Custom-cveBusterVulnerabilities_CL`
- **Transformation:** KQL adds `TimeGenerated` field
- **Data Flow:** API → DCR Stream → Transform → Custom Table

### **API Response Format**

Expected JSON response from Flask API:

```json
{
  "timestamp": "2025-11-01T12:00:00",
  "count": 10,
  "data": [
    {
      "MachineName": "WEB-SERVER-01",
      "HostId": "host-12345",
      "IPAddress": "10.0.1.50",
      "VulnId": "CVE-2024-1234",
      "Severity": "Critical",
      "CVSS": 9.8,
      ...
    }
  ]
}
```

## 🧪 Testing & Validation

### **Test API Endpoint**

```bash
# Test API accessibility
curl -H "Authorization: cvebuster-demo-key-12345" \
     http://20.84.144.179:5000/api/vulnerabilities

# Check API health
curl http://20.84.144.179:5000/health
```

### **Verify Azure Components**

```powershell
# Check DCE
Get-AzDataCollectionEndpoint -ResourceGroupName "rg-mssentinel-lab1" -Name "sentinel-mt425li7vpf6w-dce"

# Check DCR
Get-AzDataCollectionRule -ResourceGroupName "rg-mssentinel-lab1" -Name "cveBusterVulnerabilitiesDCR"

# Check table exists
Get-AzOperationalInsightsTable -ResourceGroupName "rg-mssentinel-lab1" -WorkspaceName "sentinel-mt425li7vpf6w" -TableName "cveBusterVulnerabilities_CL"
```

### **Query Data in Sentinel**

```kql
// View all ingested vulnerabilities
cveBusterVulnerabilities_CL
| order by TimeGenerated desc

// Count by severity
cveBusterVulnerabilities_CL
| summarize count() by Severity

// Critical vulnerabilities with exploits
cveBusterVulnerabilities_CL
| where Severity == "Critical" and ExploitAvailable == true

// Vulnerabilities by machine
cveBusterVulnerabilities_CL
| summarize VulnCount = count() by MachineName, tostring(Severity)
| order by VulnCount desc
```

## 🔐 Security Considerations

1. **API Key Management:**
   - Store API keys in Azure Key Vault (production)
   - Rotate keys regularly
   - Use HTTPS instead of HTTP in production

2. **Network Security:**
   - Restrict API access via NSG/firewall rules
   - Use private endpoints for production deployments
   - Consider Azure Private Link for DCE

3. **RBAC:**
   - Limit workspace access to authorized users
   - Use managed identities where possible

## 📚 Key Learnings & Notes

### **Why Connector Definition is Required**

- CCF RestApiPoller requires a `connectorDefinitionName` reference
- For full solutions, this is deployed via Content Hub
- For testing/custom connectors, create minimal definition via API
- Definition provides UI metadata in Sentinel Data Connectors gallery

### **CCF vs Traditional Connectors**

| Aspect | CCF (This Project) | Traditional |
|--------|-------------------|-------------|
| Code Required | No (configuration only) | Yes (Python/C#/Logic Apps) |
| Deployment | ARM/PowerShell | Custom deployment |
| Maintenance | Microsoft-managed runtime | Self-managed |
| Transformation | DCR with KQL | Code-based |
| Scalability | Auto-scaled by Azure | Manual scaling |

### **Best Practices Applied**

- ✅ Separate DCR, Table, and Poller configs (modular design)
- ✅ Parameterized deployment script (reusable)
- ✅ Schema validation via Table.json
- ✅ Error handling and retry logic in poller
- ✅ KQL transformation in DCR (performance optimization)

## 🛠️ Troubleshooting

### **No Data Appearing in Sentinel**

1. Check poller status in Sentinel > Data connectors
2. Verify API is accessible: `curl http://YOUR_API:5000/health`
3. Check DCR immutable ID matches poller configuration
4. Review Azure Monitor DCR metrics for errors

### **Authentication Failures**

- Ensure API key matches in both Flask app and poller config
- Check `Authorization` header format: `Authorization: <api-key>`

### **Deployment Script Errors**

- Ensure all Az PowerShell modules are installed
- Verify Azure RBAC permissions (Contributor on workspace)
- Check subscription context: `Get-AzContext`

## 🚧 Future Enhancements

- [ ] Add HTTPS support with SSL certificates
- [ ] Implement Azure Key Vault for API key storage
- [ ] Add data validation and filtering in DCR
- [ ] Create Sentinel analytics rules for vulnerabilities
- [ ] Build workbook for vulnerability visualization
- [ ] Add incremental data fetching (track last poll time)
- [ ] Implement rate limiting on Flask API
- [ ] Add logging and monitoring for API

## 📖 References

- [Microsoft Sentinel Codeless Connector Platform](https://learn.microsoft.com/en-us/azure/sentinel/create-codeless-connector)
- [Data Collection Rules Overview](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/data-collection-rule-overview)
- [Azure Sentinel GitHub - SentinelOne CCF Example](https://github.com/Azure/Azure-Sentinel/tree/master/Solutions/SentinelOne/Data%20Connectors/SentinelOne_ccp)

## 👤 Author

Built as a learning project to explore Microsoft Sentinel's Codeless Connector Framework (CCF) capabilities.

## 📄 License

This is a demo/learning project. Use at your own risk in production environments.

---

**⭐ Star this repo if you found it helpful for learning CCF!**
