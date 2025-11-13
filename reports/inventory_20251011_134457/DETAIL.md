# 资产盘点报告（只读）
- 生成时间：20251011_134457
- 输出目录：/home/MRwang/smart_assistant/reports/inventory_20251011_134457
- 关键词：greet,cam,smart_assistant,xiaomi,ai,sa-

## 主机信息
uname -a: Linux pi4b 6.12.34+rpt-rpi-v8 #1 SMP PREEMPT Debian 1:6.12.34-1+rpt1~bookworm (2025-06-26) aarch64 GNU/Linux
lsb_release: Distributor ID:	Debian Description:	Debian GNU/Linux 12 (bookworm) Release:	12 Codename:	bookworm 
Python: Python 3.11.2

## 目录与文件扫描（按关键词）
扫描路径：/opt
/home
/usr/local
/etc
/var/lib
/var/www
（仅列出名称中包含任一关键词的路径，避免全盘扫描过慢）
[目录/文件] 可能相关的路径条目：411 条，详见 paths_raw.txt

## systemd 服务（运行中与已安装）
=== 运行中服务匹配（list-units）===
  alsa-restore.service                                        loaded    active   exited  Save/Restore Sound Card State
  alsa-state.service                                          loaded    inactive dead    Manage Sound Card State (restore and store)
  apt-daily-upgrade.service                                   loaded    inactive dead    Daily apt upgrade and clean activities
  apt-daily.service                                           loaded    inactive dead    Daily apt download activities
  camfix.service                                              loaded    active   running Camera Fix Stream (Flask + OpenCV)
  cups-browsed.service                                        loaded    active   running Make remote CUPS printers available locally
  dpkg-db-backup.service                                      loaded    inactive dead    Daily dpkg database backup service
  getty-static.service                                        loaded    inactive dead    getty on tty2-tty6 if dbus and logind are not available
  greet.service                                               loaded    active   running Face greet service (Picamera2 + LBPH + ALSA TTS)
  man-db.service                                              loaded    inactive dead    Daily man-db regeneration
  NetworkManager-wait-online.service                          loaded    active   exited  Network Manager Wait Online
  plymouth-quit-wait.service                                  loaded    active   exited  Hold until boot process finishes up
  systemd-udev-settle.service                                 loaded    inactive dead    Wait for udev To Complete Device Initialization

=== 已安装的服务匹配（list-unit-files）===
alsa-restore.service                       static          -
alsa-state.service                         static          -
alsa-utils.service                         masked          enabled
apt-daily-upgrade.service                  static          -
apt-daily.service                          static          -
cam.service                                disabled        enabled
camfix.service                             enabled         enabled
container-getty@.service                   static          -
e2scrub_fail@.service                      static          -
greet.service                              enabled         enabled
NetworkManager-wait-online.service         enabled         enabled
plymouth-quit-wait.service                 static          -
systemd-boot-check-no-failures.service     disabled        disabled
systemd-networkd-wait-online.service       disabled        disabled
systemd-networkd-wait-online@.service      disabled        enabled
systemd-time-wait-sync.service             disabled        disabled
apt-daily-upgrade.timer                    enabled         enabled
apt-daily.timer                            enabled         enabled

## 定时任务（crontab 与 /etc/cron*）
=== 当前用户 crontab（关键词筛选）===
无匹配或无 crontab

=== /etc/cron.*（关键词筛选）===
/etc/cron.daily/apt-compat:9:# cron.daily time
/etc/cron.daily/apt-compat:17:    #       0 (true)    System is on main power
/etc/cron.daily/apt-compat:18:    #       1 (false)   System is not on main power
/etc/cron.daily/apt-compat:54:# run daily job
/etc/cron.daily/apt-compat:55:exec /usr/lib/apt/apt.systemd.daily
/etc/cron.daily/man-db:3:# man-db cron daily
/etc/cron.hourly/fake-hwclock:4:# a power failure or other crash

=== /etc/crontab（关键词筛选）===
19:25 6	* * *	root	test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }

## 设备占用（摄像头/音频）
=== 摄像头设备 ===
crw-rw----+ 1 root video 81, 8 Oct 10 18:17 /dev/video0

=== 摄像头占用（lsof /dev/video*）===
COMMAND   PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
python3   765 MRwang   15u   CHR   81,8      0t0  604 /dev/video0
python3   765 MRwang   16u   CHR   81,0      0t0  591 /dev/video13
python3   765 MRwang   17u   CHR   81,1      0t0  592 /dev/video14
python3   765 MRwang   18u   CHR   81,2      0t0  593 /dev/video15
python3   765 MRwang   19u   CHR   81,3      0t0  594 /dev/video16
pipewire  913 MRwang   55u   CHR   81,8      0t0  604 /dev/video0
pipewire  913 MRwang   56u   CHR   81,0      0t0  591 /dev/video13
pipewire  913 MRwang   59u   CHR   81,1      0t0  592 /dev/video14
pipewire  913 MRwang   60u   CHR   81,2      0t0  593 /dev/video15
pipewire  913 MRwang   61u   CHR   81,3      0t0  594 /dev/video16
wireplumb 915 MRwang   39u   CHR   81,8      0t0  604 /dev/video0
wireplumb 915 MRwang   40u   CHR   81,0      0t0  591 /dev/video13
wireplumb 915 MRwang   41u   CHR   81,1      0t0  592 /dev/video14
wireplumb 915 MRwang   42u   CHR   81,2      0t0  593 /dev/video15
wireplumb 915 MRwang   43u   CHR   81,3      0t0  594 /dev/video16
无占用

=== 音频采集设备（arecord -l）===
**** List of CAPTURE Hardware Devices ****
card 1: Device [USB PnP Sound Device], device 0: USB Audio [USB Audio]
  Subdevices: 1/1
  Subdevice #0: subdevice #0

=== 音频输出设备（aplay -l）===
**** List of PLAYBACK Hardware Devices ****
card 0: sndrpihifiberry [snd_rpi_hifiberry_dac], device 0: HifiBerry DAC HiFi pcm5102a-hifi-0 [HifiBerry DAC HiFi pcm5102a-hifi-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0

## 监听端口与进程
=== 所有监听端口（TCP/UDP）===
Netid State  Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess                                                     
udp   UNCONN 0      0            0.0.0.0:56506      0.0.0.0:*                                                               
udp   UNCONN 0      0            0.0.0.0:5353       0.0.0.0:*                                                               
udp   UNCONN 0      0                  *:57291            *:*                                                               
udp   UNCONN 0      0                  *:5353             *:*                                                               
tcp   LISTEN 0      128        127.0.0.1:631        0.0.0.0:*                                                               
tcp   LISTEN 0      128          0.0.0.0:22         0.0.0.0:*                                                               
tcp   LISTEN 0      2048         0.0.0.0:5000       0.0.0.0:*    users:(("gunicorn",pid=778,fd=5),("gunicorn",pid=763,fd=5))
tcp   LISTEN 0      128            [::1]:631           [::]:*                                                               
tcp   LISTEN 0      128             [::]:22            [::]:*                                                               

=== 可疑老端口检查：5050 ===
端口 5050 未被监听

## 关键服务存在性（只读）
=== mosquitto（MQTT）===
未发现 mosquitto.service（这不一定是问题）

=== 其他可疑服务（再次用关键词扫一遍）===
alsa-restore.service                       static          -
alsa-state.service                         static          -
alsa-utils.service                         masked          enabled
apt-daily-upgrade.service                  static          -
apt-daily.service                          static          -
cam.service                                disabled        enabled
camfix.service                             enabled         enabled
container-getty@.service                   static          -
e2scrub_fail@.service                      static          -
greet.service                              enabled         enabled
NetworkManager-wait-online.service         enabled         enabled
plymouth-quit-wait.service                 static          -
systemd-boot-check-no-failures.service     disabled        disabled
systemd-networkd-wait-online.service       disabled        disabled
systemd-networkd-wait-online@.service      disabled        enabled
systemd-time-wait-sync.service             disabled        disabled
apt-daily-upgrade.timer                    enabled         enabled
apt-daily.timer                            enabled         enabled
盘点完成：
- 主报告：/home/MRwang/smart_assistant/reports/inventory_20251011_134457/DETAIL.md
- 目录匹配：/home/MRwang/smart_assistant/reports/inventory_20251011_134457/paths_raw.txt
- systemd 服务：/home/MRwang/smart_assistant/reports/inventory_20251011_134457/systemd_services.txt
- cron 匹配：/home/MRwang/smart_assistant/reports/inventory_20251011_134457/cron_matches.txt
- 设备/音频：/home/MRwang/smart_assistant/reports/inventory_20251011_134457/devices_audio_video.txt
- 端口：/home/MRwang/smart_assistant/reports/inventory_20251011_134457/listening_ports.txt

后续建议：
1) 打开 SUMMARY.txt / DETAIL.md 先过一遍，确认哪些是真正的旧项目资产。
2) 若发现漏报，调整 PATTERNS 或 SCAN_DIRS 再跑一次本脚本。
3) 盘点确认后，再进行“快照→停旧→建新家→只读隔离”的下一步。
