# cveBuster Flask API Server Setup

## Ubuntu VM Setup Instructions

### 1. Prerequisites
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Python 3 and pip
sudo apt install python3 python3-pip -y

# Verify installation
python3 --version
pip3 --version
```

### 2. File Placement
Transfer these files to your Ubuntu VM Desktop:
- `generate_data.py` → `~/Desktop/generate_data.py`
- `app.py` → `~/Desktop/app.py`
- `requirements.txt` → `~/Desktop/requirements.txt`

### 3. Generate Initial Data
```bash
cd ~/Desktop
python3 generate_data.py
```
This creates `cvebuster_data.json` with 10 fresh records.

### 4. Install Flask
```bash
pip3 install -r requirements.txt
```

### 5. Run the Flask App
```bash
python3 app.py
```

The server will start on `http://0.0.0.0:5000` (accessible externally on port 5000)

### 6. Open Firewall (if needed)
```bash
# Allow port 5000
sudo ufw allow 5000/tcp
sudo ufw status
```

---

## Testing the API

### Health Check (No Auth Required)
```bash
curl http://20.84.144.179:5000/health
```

### Get All Vulnerabilities (API Key Required)
```bash
curl -H 'Authorization: cvebuster-demo-key-12345' http://20.84.144.179:5000/api/vulnerabilities
```

### Get Record Count (No Auth)
```bash
curl http://20.84.144.179:5000/api/vulnerabilities/count
```

### Get API Info
```bash
curl http://20.84.144.179:5000/
```

---

## API Configuration

**API Key:** `cvebuster-demo-key-12345`

**Endpoints:**
- `GET /` - API information
- `GET /health` - Health check
- `GET /api/vulnerabilities` - Get all vulnerability records (requires API key)
- `GET /api/vulnerabilities/count` - Get count of records (no auth)

---

## Refreshing Data

To generate fresh vulnerability data with new timestamps:
```bash
cd ~/Desktop
python3 generate_data.py
```

The API will automatically serve the updated data on the next request (no restart needed).

---

## Production Notes

For production use:
1. Use a proper WSGI server (gunicorn, uWSGI)
2. Use environment variables for API keys
3. Implement HTTPS
4. Add rate limiting
5. Use a proper secrets management system

**Example with Gunicorn:**
```bash
pip3 install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```
