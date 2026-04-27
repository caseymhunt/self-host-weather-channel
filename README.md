# WeatherStar 4000+ Home Streaming Setup

A personal documentation of lessons learned while setting up [ws4kp](https://github.com/netbymatt/ws4kp) for home streaming via ws4channels, xTeVe, Plex, and Apple TV.

---

## Stack Overview

```
ws4kp → ws4channels → xTeVe → Plex → Apple TV
```

| Component | Image | Port | Role |
|---|---|---|---|
| ws4kp | `ghcr.io/netbymatt/ws4kp:latest` | 8080 | Renders the WeatherStar 4000 UI in a headless browser |
| ws4channels | `ghcr.io/rice9797/ws4channels:latest` | 9798 | Captures ws4kp via Puppeteer and encodes it as an HLS stream |
| xTeVe | `dnsforge/xteve:latest` | 34400 | Presents the stream to Plex as a fake HDHomeRun tuner |
| Plex | — | 32400 | Media server; serves the channel to Plex clients |

---

## Prerequisites

Before starting, ensure the following are in place on your media server:

**Docker and Docker Compose**
Docker is the container runtime that runs all the components in this stack. Install it with:
```bash
curl -fsSL https://get.docker.com | sh
```
Docker Compose is included with modern Docker installations. Verify both are working:
```bash
docker --version
docker compose version
```

**Make**
The `make` command is used to manage the project. Install it with:
```bash
sudo apt install make
```

**Plex Media Server**
Plex must already be installed and running on your server or another machine on your network. Download Plex from [plex.tv](https://www.plex.tv). A Plex Pass subscription is **not required** to watch Live TV on your local network — only DVR recording requires Plex Pass. Note that as of March 2026, streaming outside your home network (remotely) does require a paid Plex plan.

**Your server's local IP address**
You will need this throughout setup. Find it with:
```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
```
Make a note of the address (e.g. `192.168.1.168`). Wherever you see `SERVER_IP` in this guide, substitute your address.

---

## First Time Setup

### Step 1: Clone this repository
```bash
git clone <your-repo-url> ~/weather-channel
cd ~/weather-channel
```

Your project directory should look like this:

```
~/weather-channel/
├── docker-compose.yml   # Stack definition
├── Makefile             # Project commands
├── settings.env         # Your location, display settings and screen toggles
├── messages.txt         # Your scrolling banner messages
├── messages.env         # Generated from messages.txt — do not edit directly
└── .gitignore
```

### Step 2: Review your settings
Open `settings.env` and update `ZIP_CODE` to your local zip code. You can also enable or disable weather screens — each checkbox line controls one screen. Change `true` to `false` for any screens you don't want.

### Step 3: Edit your messages
Open `messages.txt` and replace the example messages with your own:
```bash
nano messages.txt
```
One message per line. Do not use the `|` character. Save with `Ctrl+X`, then `Y`, then `Enter`.

### Step 4: Start the containers
```bash
make up
```
This generates `messages.env` from your `messages.txt` and starts all three containers. The first run will download the Docker images, which may take a few minutes depending on your connection.

Verify all three containers are running:
```bash
docker ps
```
You should see `ws4kp`, `ws4channels`, and `xteve` all listed with a status of `Up`.

### Step 5: Verify the stream
Before setting up Plex, confirm the stream is working by opening this URL in a browser or VLC on any device on your network:
```
http://SERVER_IP:9798/stream/stream.m3u8
```
You should see the WeatherStar 4000 display after a few seconds. If it does not appear, check the container logs:
```bash
make logs
```

### Step 6: Configure xTeVe
Open the xTeVe web UI at `http://SERVER_IP:34400/web/` and complete the setup wizard:

1. When asked for a playlist source, enter:
   ```
   http://SERVER_IP:9798/playlist.m3u
   ```
2. When asked for EPG source, select **XEPG**
3. After the wizard completes, go to **Settings → General** and confirm:
   - **Buffer** is set to `FFmpeg`
   - **FFmpeg path** is set to `/usr/bin/ffmpeg`
   - **Buffer Size** is set to `3072 KB`
4. Go to **XMLTV** and add a new source:
   ```
   http://SERVER_IP:9798/guide.xml
   ```
5. Go to **Mapping** and ensure the WeatherStar 4000 channel is toggled **Active**
6. Save and restart xTeVe:
   ```bash
   make restart
   ```

### Step 7: Configure Plex Live TV
1. In Plex, go to **Settings → Live TV & DVR → Set Up Plex DVR**
2. Plex should auto-discover xTeVe as a tuner on your network. If it does not, enter your server IP manually: `http://SERVER_IP:34400`
3. When prompted for guide data, enter the xTeVe XMLTV URL:
   ```
   http://SERVER_IP:34400/xmltv/xteve.xml
   ```
4. Complete the wizard and confirm the WeatherStar 4000 channel appears in your channel list

### Step 8: Test on Apple TV
Open the Plex app on your Apple TV, navigate to **Live TV**, and tune the WeatherStar channel. The stream may take a few seconds to start. If it loads indefinitely, refer to the Troubleshooting section below.

---

## Configuration Notes

Hard-won lessons from initial setup. Refer to these before making changes.

### xTeVe Buffer Size: 3072 KB
Higher values (e.g. 8192 KB) cause Plex to time out after ~20 seconds while waiting for the buffer to fill, resulting in an infinite loading spinner on the client. 3072 KB fills quickly enough to satisfy Plex's timeout threshold while still providing smooth playback. Set this in **xTeVe → Settings → General → Buffer Size**.

### xTeVe M3U Endpoint is Case-Sensitive
The correct M3U URL uses a **lowercase** path:
```
http://SERVER_IP:34400/m3u/xteve.m3u
```
The capitalized variant (`/M3U/`) returns the UPnP device XML instead of the playlist and will not work.

### xTeVe Must Use FFmpeg Buffer Mode
Without FFmpeg buffering enabled, xTeVe issues a 302 redirect to the ws4channels stream URL. Plex does not follow this redirect when tuning, resulting in a tuning failure on all clients. Set **xTeVe → Settings → General → Buffer** to `FFmpeg` and ensure the FFmpeg path is set to `/usr/bin/ffmpeg`.

### xTeVe EPG Source Must Be Set to XEPG, Not PMS
PMS mode does not expose an XMLTV endpoint, but Plex requires either a valid XMLTV URL or a zip code during DVR setup and will not allow you to skip this step. Use **XEPG** mode in xTeVe and add the ws4channels XMLTV guide as the source:
```
http://SERVER_IP:9798/guide.xml
```
This provides real hourly "Local Weather" guide entries in Plex rather than a blank schedule.

### ws4channels Default Encoding Settings Are Optimal
Custom `VIDEO_OPTIONS` and `FRAME_RATE` overrides introduced artifacts and instability on the Dell Optiplex 3050 SFF (Core i5-7500). The out-of-the-box defaults produce the cleanest stream on this hardware. Do not set custom encoding options without testing in VLC first before enabling in Plex.

### Do Not Enable Kiosk Mode in settings.env
`WSQS_settings_kiosk_checkbox=true` causes ws4channels/Puppeteer to capture a zoomed-in crop of the weather display rather than the full screen, resulting in roughly 1/4 of the image being visible in the stream. Kiosk mode scales the display to fill the entire browser viewport, which conflicts with Puppeteer's fixed capture window. Leave this setting out of `settings.env` entirely. It has no useful effect on the stream and breaks the video output.

### Do Not Set VIDEO_OPTIONS to CRF 18 or Lower
Higher quality CRF values significantly increase CPU load during live encoding and can render the server unresponsive. If encoding quality needs improvement, use Intel Quick Sync hardware encoding instead:
```yaml
devices:
  - /dev/dri:/dev/dri
environment:
  - VIDEO_OPTIONS=-c:v h264_qsv -b:v 2000k
```
Verify Quick Sync is available first with `ls /dev/dri` — you should see `card0` and `renderD128`.

---

## Project Management

### Using Make
Always use `make` commands instead of running `docker compose` directly. This ensures `messages.env` is always regenerated from `messages.txt` before any compose command runs. Running `docker compose up -d` directly will fail if `messages.env` does not exist.

| Command | Effect |
|---|---|
| `make up` | Generate `messages.env` and start all containers |
| `make down` | Stop all containers |
| `make restart` | Restart all containers without re-reading env files (useful for diagnostics) |
| `make preview` | Print the ws4kp preview URL for your browser |
| `make logs` | Tail logs for all containers |

> **Note:** To apply changes to `settings.env` or `messages.txt`, always use `make down && make up` — a plain `make restart` will not re-read environment files.

### Managing Display Settings
All user configuration lives in `settings.env` — location, display toggles, and playback preferences. Edit this file directly to customize your setup. Unlike `messages.env`, this file is hand-edited and committed to git.

| Setting | Description |
|---|---|
| `ZIP_CODE` | Your local zip code, used by ws4channels for weather data |
| `WSQS_latLonQuery` | Your location as seen by ws4kp — set to your zip code |
| `WSQS_settings_*` | Display and playback preferences |
| `WSQS_*_checkbox` | Enable or disable individual weather screens (`true`/`false`) |

After editing, apply changes with:
```bash
make down && make up
```

### Managing Scrolling Banner Messages
The scrolling banner messages displayed at the bottom of the WeatherStar screen are managed via `messages.txt`. Edit this file to add, remove, or change messages — one message per line. Lines starting with `#` and blank lines are ignored.

```
# This is a comment and will be ignored
Enjoy unlimited weather vibes, Babe
Feeling sad or angry? Try hugging a dog
Have you eaten today, Rachel?
```

After editing, apply changes with:
```bash
make down && make up
```

> **Note:** Do not use the pipe character (`|`) in messages — it is used as a delimiter when the file is processed and will break message formatting.

> **Note:** `make restart` is not sufficient to apply message changes — the ws4kp container must be fully recreated to re-read its environment. Always use `make down && make up`.

The `messages.env` file is generated automatically from `messages.txt` and is excluded from git via `.gitignore`. Do not edit it directly.

---

## Useful URLs

| Resource | URL |
|---|---|
| ws4kp web UI | `http://SERVER_IP:8080` |
| ws4kp preview (with location & kiosk) | run `make preview` to get your URL — opens at root `/` so the redirect chain injects all settings |
| ws4channels raw stream | `http://SERVER_IP:9798/stream/stream.m3u8` |
| ws4channels playlist | `http://SERVER_IP:9798/playlist.m3u` |
| ws4channels guide | `http://SERVER_IP:9798/guide.xml` |
| xTeVe web UI | `http://SERVER_IP:34400/web/` |
| xTeVe M3U | `http://SERVER_IP:34400/m3u/xteve.m3u` |
| xTeVe XMLTV | `http://SERVER_IP:34400/xmltv/xteve.xml` |

> Replace `SERVER_IP` with your media server's local IP address (e.g. `192.168.1.168`). For the ws4kp preview, use `make preview` rather than the bare web UI URL — it includes your location and kiosk mode automatically.

---

## Troubleshooting

**Infinite loading spinner on Apple TV**
Check the xTeVe buffer size. If it's above 3072 KB, reduce it. Plex has a ~20 second timeout before it drops the tuning connection.

**"Could not tune channel" on Plex desktop**
The Plex desktop app is less tolerant of HLS streams than the Apple TV app. Since the Apple TV is the target client, this error can be ignored if playback works on the TV.

**xTeVe M3U returns UPnP XML instead of a playlist**
You are using the wrong URL casing. Use `/m3u/` (lowercase), not `/M3U/`.

**Verifying environment variables inside a container**
To confirm what values a running container has actually loaded, use `docker exec` to inspect its environment directly. This is useful for verifying that changes to `settings.env` or `messages.env` have been picked up after a restart:
```bash
# Check a specific variable in ws4kp
docker exec ws4kp env | grep customText

# Check all ws4kp environment variables
docker exec ws4kp env | grep WSQS

# Check ws4channels environment
docker exec ws4channels env
```
If the values shown don't match your config files, the container needs a full `make down && make up` to pick up the changes — `make restart` is not sufficient.

**Stream works in VLC but not in Plex**
xTeVe is likely in passthrough/redirect mode instead of FFmpeg buffer mode. Enable FFmpeg buffering in xTeVe Settings → General.
