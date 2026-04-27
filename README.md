# WeatherStar 4000+ Home Streaming Setup

![Weather Channel running on Plex](screenshot.png)

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

## Useful URLs

| Resource | URL |
|---|---|
| ws4kp web UI | `http://SERVER_IP:8080` |
| ws4channels raw stream | `http://SERVER_IP:9798/stream/stream.m3u8` |
| ws4channels playlist | `http://SERVER_IP:9798/playlist.m3u` |
| ws4channels guide | `http://SERVER_IP:9798/guide.xml` |
| xTeVe web UI | `http://SERVER_IP:34400/web/` |
| xTeVe M3U | `http://SERVER_IP:34400/m3u/xteve.m3u` |
| xTeVe XMLTV | `http://SERVER_IP:34400/xmltv/xteve.xml` |

> Replace `SERVER_IP` with your media server's local IP address (e.g. `192.168.1.168`).

---

## Troubleshooting

**Infinite loading spinner on Apple TV**
Check the xTeVe buffer size. If it's above 3072 KB, reduce it. Plex has a ~20 second timeout before it drops the tuning connection.

**"Could not tune channel" on Plex desktop**
The Plex desktop app is less tolerant of HLS streams than the Apple TV app. Since the Apple TV is the target client, this error can be ignored if playback works on the TV.

**xTeVe M3U returns UPnP XML instead of a playlist**
You are using the wrong URL casing. Use `/m3u/` (lowercase), not `/M3U/`.

**Stream works in VLC but not in Plex**
xTeVe is likely in passthrough/redirect mode instead of FFmpeg buffer mode. Enable FFmpeg buffering in xTeVe Settings → General.
