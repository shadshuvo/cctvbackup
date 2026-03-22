# 📹 Auto-Sync CCTV to Google Drive (Rclone) can use any cloud from Rclone

A lightweight, automated pipeline designed to bridge local CCTV FTP storage (NVR) with Google Drive. This project ensures local server storage never exceeds capacity while maintaining a 30-day rolling cloud archive.

---

## 🚀 The Problem

Most NVRs/CCTV systems support FTP, but local server storage is expensive and limited. High-traffic web servers (like a streaming platform) need to keep disk I/O low and storage available for site performance. Manual cleanup is error-prone and time-consuming.

---

## ✨ Features

- **🔄 Zero-Threshold Sync:** Automatically sweeps local footage to the cloud.
- **⚡ Throttled Migration:** Uses `nice`, `ionice`, and `bwlimit` to ensure zero impact on web server performance during transfers.
- **🗂️ Smart Retention:**
  - Keep **30 days** of footage on Google Drive.
  - Keep **7 days** of execution logs locally.
- **📲 Real-time Alerts:** Integrated Telegram Bot notifications for sync failures.
- **📷 NVR Friendly:** Uses `--min-age` to avoid moving files currently being written by the NVR.
- **🔒 Secure by Design:** Sensitive credentials are loaded from environment variables — never hard-coded.

---

## 🛠️ Tech Stack

| Component   | Technology              |
|-------------|-------------------------|
| Server OS   | Ubuntu / aaPanel        |
| Engine      | Bash & Rclone           |
| Storage     | Google Drive API        |
| Monitoring  | Telegram Bot API        |

---

## 📦 Installation

### 1. 🔧 Configure Rclone

Install Rclone and set up your Google Drive remote:

```bash
curl https://rclone.org/install.sh | sudo bash
rclone config
```

Follow the interactive prompts. Name your remote `gdrive-remote` to match the default in `cctv.sh`, or update `REMOTE_NAME` in the script.

---

### 2. 📁 Setup Directories

Create the folder that your NVR pushes footage into via FTP:

```bash
mkdir -p /www/wwwroot/default/cctv/main
mkdir -p /www/wwwroot/default/cctv/logs
```

---

### 3. 🚀 Deploy Script

Upload `cctv.sh` to your server and make it executable:

```bash
chmod +x cctv.sh
```

---

### 4. 🔐 Set Environment Variables

**Never hard-code your Telegram credentials.** Export them securely before running the script:

```bash
export TELEGRAM_BOT_TOKEN="your_bot_token_here"
export TELEGRAM_CHAT_ID="your_chat_id_here"
```

For persistent configuration, add these lines to `/etc/environment` or a secured `.env` file that is sourced by cron (and is listed in `.gitignore`).

> **Tip:** Create your Telegram bot via [@BotFather](https://t.me/BotFather) and get your Chat ID from [@userinfobot](https://t.me/userinfobot).

---

### 5. ⏰ Automation via Cron

Add a Cron Job in aaPanel (recommended: **01:30 AM Daily**):

```bash
# Open crontab
crontab -e

# Add this line — source credentials from a secured file to avoid
# exposing them in process lists (ps) or cron logs.
30 1 * * * . /www/wwwroot/default/cctv/.env && bash /www/wwwroot/default/cctv/cctv.sh
```

Create `/www/wwwroot/default/cctv/.env` (permissions `600`, **not committed to Git**):

```bash
export TELEGRAM_BOT_TOKEN="your_bot_token_here"
export TELEGRAM_CHAT_ID="your_chat_id_here"
```

Secure the file:

```bash
chmod 600 /www/wwwroot/default/cctv/.env
```

---

## ⚙️ Configuration Reference

Edit the top of `cctv.sh` to match your environment:

| Variable        | Default Value                              | Description                          |
|-----------------|--------------------------------------------|--------------------------------------|
| `SOURCE_DIR`    | `/www/wwwroot/default/cctv/main`           | Local folder NVR pushes footage into |
| `CONFIG_PATH`   | `/www/wwwroot/default/cctv/rclone.conf`    | Path to your rclone config file      |
| `REMOTE_NAME`   | `gdrive-remote`                            | Rclone remote name from rclone.conf  |
| `REMOTE_DIR`    | `gdrive-remote:Scripts/cctv`              | Destination folder on Google Drive   |
| `LOG_DIR`       | `/www/wwwroot/default/cctv/logs`           | Local directory for log files        |

---

## 📊 How It Works

```
NVR (Camera) ──FTP──► Local Server (/cctv/main)
                              │
                    [cctv.sh runs at 01:30 AM]
                              │
              ┌───────────────┼───────────────┐
              │               │               │
        🗑️ Delete        📤 Move files     📋 Copy log
        GDrive files     to GDrive         to GDrive
        older >30d       (throttled)       /Logs
              │               │
        🔔 Telegram alert on any failure
```

---

## 🔒 Security Notes

- ✅ `rclone.conf` is listed in `.gitignore` — **never commit it**.
- ✅ Telegram tokens and chat IDs are loaded from **environment variables**.
- ✅ `.env` files are excluded from version control via `.gitignore`.
- ⚠️ Restrict permissions on your rclone config: `chmod 600 /www/wwwroot/default/cctv/rclone.conf`
- ⚠️ For production use, consider using **GitHub Secrets** and a CI/CD pipeline to manage deployments securely.

---

## 📁 Project Structure

```
cctvbackup/
├── cctv.sh         # Main sync & management script
├── .gitignore      # Excludes rclone.conf, .env, and logs
└── README.md       # This file
```

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).

---

*Made with ❤️ by [Shadman Shuvo](https://github.com/shadshuvo)*
