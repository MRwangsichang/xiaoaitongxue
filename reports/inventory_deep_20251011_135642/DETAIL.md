# 深度资产盘点报告（只读）
- 生成时间：20251011_135642
- 关键词：greet,cam,smart_assistant,xiaomi,ai,sa-,vision,face,opencv,vosk,iflytek,asr,tts,edge-tts,lirc,ir,kugou,music,display,gc9a01,mqtt,mosquitto,5050,1883,rtsp

## 目录与文件（深度扫描 maxdepth=6）
[路径] 匹配到 1286 条，详见 paths_raw.txt

## systemd（服务/计时器/套接字）
== 运行中服务（list-units）匹配 ==
  alsa-restore.service                                        loaded    active   exited  Save/Restore Sound Card State
  alsa-state.service                                          loaded    inactive dead    Manage Sound Card State (restore and store)
  apt-daily-upgrade.service                                   loaded    inactive dead    Daily apt upgrade and clean activities
  apt-daily.service                                           loaded    inactive dead    Daily apt download activities
  camfix.service                                              loaded    active   running Camera Fix Stream (Flask + OpenCV)
  cups-browsed.service                                        loaded    active   running Make remote CUPS printers available locally
  dpkg-db-backup.service                                      loaded    inactive dead    Daily dpkg database backup service
  getty-static.service                                        loaded    inactive dead    getty on tty2-tty6 if dbus and logind are not available
  greet.service                                               loaded    active   running Face greet service (Picamera2 + LBPH + ALSA TTS)
  lightdm.service                                             loaded    active   running Light Display Manager
  man-db.service                                              loaded    inactive dead    Daily man-db regeneration
  NetworkManager-wait-online.service                          loaded    active   exited  Network Manager Wait Online
  plymouth-quit-wait.service                                  loaded    active   exited  Hold until boot process finishes up
  rp1-test.service                                            loaded    active   exited  Check for RP1 displays for Xorg
  sshswitch.service                                           loaded    inactive dead    Turn on SSH if /boot/ssh or /boot/firmware/ssh is present
  systemd-firstboot.service                                   loaded    inactive dead    First Boot Wizard
  systemd-tmpfiles-clean.service                              loaded    inactive dead    Cleanup of Temporary Directories
  systemd-tmpfiles-setup.service                              loaded    active   exited  Create System Files and Directories
  systemd-udev-settle.service                                 loaded    inactive dead    Wait for udev To Complete Device Initialization
  user-runtime-dir@1000.service                               loaded    active   exited  User Runtime Directory /run/user/1000
  user-runtime-dir@105.service                                loaded    active   exited  User Runtime Directory /run/user/105

== 已安装服务（list-unit-files）匹配 ==
boot-firmware.mount                        generated       -
alsa-restore.service                       static          -
alsa-state.service                         static          -
alsa-utils.service                         masked          enabled
apt-daily-upgrade.service                  static          -
apt-daily.service                          static          -
cam.service                                disabled        enabled
camfix.service                             enabled         enabled
container-getty@.service                   static          -
display-manager.service                    alias           -
e2scrub_fail@.service                      static          -
greet.service                              enabled         enabled
NetworkManager-wait-online.service         enabled         enabled
plymouth-quit-wait.service                 static          -
rpi-display-backlight.service              enabled         enabled
saned@.service                             indirect        enabled
systemd-boot-check-no-failures.service     disabled        disabled
systemd-firstboot.service                  static          -
systemd-networkd-wait-online.service       disabled        disabled
systemd-networkd-wait-online@.service      disabled        enabled
systemd-time-wait-sync.service             disabled        disabled
user-runtime-dir@.service                  static          -
vncserver-virtuald.service                 disabled        enabled
wpa_supplicant-wired@.service              disabled        enabled
first-boot-complete.target                 static          -
graphical.target                           indirect        enabled
apt-daily-upgrade.timer                    enabled         enabled
apt-daily.timer                            enabled         enabled

== 计时器（list-timers） ==
NEXT                        LEFT           LAST                        PASSED        UNIT                         ACTIVATES
Sat 2025-10-11 15:01:02 CST 1h 4min left   Fri 2025-10-10 14:41:17 CST 23h ago       man-db.timer                 man-db.service
Sat 2025-10-11 23:54:02 CST 9h left        Fri 2025-10-10 14:48:03 CST 23h ago       apt-daily.timer              apt-daily.service
Sun 2025-10-12 00:00:00 CST 10h left       Sat 2025-10-11 13:23:56 CST 32min ago     dpkg-db-backup.timer         dpkg-db-backup.service
Sun 2025-10-12 00:00:00 CST 10h left       Sat 2025-10-11 13:23:56 CST 32min ago     logrotate.timer              logrotate.service
Sun 2025-10-12 03:10:17 CST 13h left       Thu 2025-10-09 15:49:36 CST 1 day 22h ago e2scrub_all.timer            e2scrub_all.service
Sun 2025-10-12 06:34:31 CST 16h left       Sat 2025-10-11 13:37:16 CST 19min ago     apt-daily-upgrade.timer      apt-daily-upgrade.service
Sun 2025-10-12 13:38:22 CST 23h left       Sat 2025-10-11 13:38:22 CST 18min ago     systemd-tmpfiles-clean.timer systemd-tmpfiles-clean.service
Mon 2025-10-13 01:06:32 CST 1 day 11h left Thu 2025-10-09 15:56:16 CST 1 day 22h ago fstrim.timer                 fstrim.service

8 timers listed.

== 套接字（list-sockets） ==
无匹配

== 默认目标 ==
graphical.target

## 定时任务（所有用户 + 系统）
== /etc/cron.* 中的匹配 ==
/etc/cron.d/.placeholder:2:# This file is a simple placeholder to keep dpkg from removing this directory
/etc/cron.daily/apt-compat:7:# runs as much as possible to avoid hitting the mirrors all at the
/etc/cron.daily/apt-compat:9:# cron.daily time
/etc/cron.daily/apt-compat:17:    #       0 (true)    System is on main power
/etc/cron.daily/apt-compat:18:    #       1 (false)   System is not on main power
/etc/cron.daily/apt-compat:54:# run daily job
/etc/cron.daily/apt-compat:55:exec /usr/lib/apt/apt.systemd.daily
/etc/cron.daily/.placeholder:2:# This file is a simple placeholder to keep dpkg from removing this directory
/etc/cron.daily/man-db:3:# man-db cron daily
/etc/cron.hourly/.placeholder:2:# This file is a simple placeholder to keep dpkg from removing this directory
/etc/cron.hourly/fake-hwclock:4:# a power failure or other crash
/etc/cron.monthly/.placeholder:2:# This file is a simple placeholder to keep dpkg from removing this directory
/etc/cron.weekly/.placeholder:2:# This file is a simple placeholder to keep dpkg from removing this directory
/etc/cron.yearly/.placeholder:2:# This file is a simple placeholder to keep dpkg from removing this directory

== /etc/crontab ==
19:25 6	* * *	root	test -x /usr/sbin/anacron || { cd / && run-parts --report /etc/cron.daily; }

== 所有用户 crontab（尝试枚举） ==

## 开机自启与桌面自启
== 用户级自启 ~/.config/autostart/*.desktop ==
无匹配

== 系统级自启 /etc/xdg/autostart/ ==
/etc/xdg/autostart/autotouch.desktop:7:NoDisplay=true
/etc/xdg/autostart/xwayauth.desktop:7:NoDisplay=true
/etc/xdg/autostart/pulseaudio.desktop:71:Comment[id]=Memulai Sistem Suara PulseAudio
/etc/xdg/autostart/pwrkey.desktop:7:NoDisplay=true
/etc/xdg/autostart/xdg-user-dirs.desktop:4:TryExec=xdg-user-dirs-update
/etc/xdg/autostart/xdg-user-dirs.desktop:5:Exec=xdg-user-dirs-update
/etc/xdg/autostart/xdg-user-dirs.desktop:7:NoDisplay=true
/etc/xdg/autostart/polkit-mate-authentication-agent-1.desktop:96:Comment[is]=PolicyKit auðkenningarþjónn fyrir MATE-skjáborðið
/etc/xdg/autostart/polkit-mate-authentication-agent-1.desktop:127:NoDisplay=true
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:23:Name[eu]=Ziurtagirien/gakoen biltegia
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:25:Name[fi]=Varmenne- ja avainsäilö
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:43:Name[lt]=Liudijimų ir raktų saugykla
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:96:Comment[eu]=GNOMEren gako-sorta: PKCS#11 osagaia
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:98:Comment[fi]=Gnomen avainnippu: PKCS#11-komponentti
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:101:Comment[gd]=Dul-iuchrach GNOME: Co-phàirt PKCS#11
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:116:Comment[lv]=GNOME atslēgu saišķis — PKCS#11 komponente
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:130:Comment[pt_BR]=Chaveiro do GNOME: Componente PKCS#11
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:134:Comment[sl]=Zbirka ključev GNOME: enota PKCS#11
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:151:NoDisplay=true
/etc/xdg/autostart/gnome-keyring-pkcs11.desktop:152:X-GNOME-Autostart-Phase=PreDisplayServer
/etc/xdg/autostart/xcompmgr.desktop:5:NoDisplay=true
/etc/xdg/autostart/xdg-user-dirs-kde.desktop:4:TryExec=xdg-user-dirs-update
/etc/xdg/autostart/xdg-user-dirs-kde.desktop:5:Exec=xdg-user-dirs-update
/etc/xdg/autostart/xdg-user-dirs-kde.desktop:7:NoDisplay=true
/etc/xdg/autostart/env-display.desktop:3:Name=env_display
/etc/xdg/autostart/env-display.desktop:4:Comment=Set display variable for systemd user services
/etc/xdg/autostart/env-display.desktop:5:NoDisplay=false
/etc/xdg/autostart/env-display.desktop:6:Exec=/usr/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY
/etc/xdg/autostart/pprompt.desktop:5:NoDisplay=true
/etc/xdg/autostart/squeekboard.desktop:7:NoDisplay=true
/etc/xdg/autostart/gnome-keyring-ssh.desktop:24:Name[fi]=SSH-avainten agentti
/etc/xdg/autostart/gnome-keyring-ssh.desktop:27:Name[gd]=Àidseant iuchair SSH
/etc/xdg/autostart/gnome-keyring-ssh.desktop:96:Comment[fi]=Gnomen avainnippu: SSH-agentti
/etc/xdg/autostart/gnome-keyring-ssh.desktop:114:Comment[lv]=GNOME atslēgu saišķis — SSH aģents
/etc/xdg/autostart/gnome-keyring-ssh.desktop:129:Comment[pt_BR]=Chaveiro do GNOME: Agente SSH
/etc/xdg/autostart/gnome-keyring-ssh.desktop:133:Comment[sl]=Zbirka ključev GNOME: agent SSH
/etc/xdg/autostart/gnome-keyring-ssh.desktop:150:X-GNOME-Autostart-Phase=PreDisplayServer
/etc/xdg/autostart/gnome-keyring-secrets.desktop:24:Name[fi]=Salaisuuksien säilöntäpalvelu
/etc/xdg/autostart/gnome-keyring-secrets.desktop:27:Name[gd]=Seirbheis stòrais dhìomhair
/etc/xdg/autostart/gnome-keyring-secrets.desktop:96:Comment[fi]=Gnomen avainnippu: Salainen palvelu
/etc/xdg/autostart/gnome-keyring-secrets.desktop:99:Comment[gd]=Dul-iuchrach GNOME: Seirbheis dhìomhair
/etc/xdg/autostart/gnome-keyring-secrets.desktop:114:Comment[lv]=GNOME atslēgu saišķis — slepenais serviss
/etc/xdg/autostart/gnome-keyring-secrets.desktop:129:Comment[pt_BR]=Chaveiro do GNOME: Serviço secreto
/etc/xdg/autostart/gnome-keyring-secrets.desktop:133:Comment[sl]=Zbirka ključev GNOME: skrite storitve
/etc/xdg/autostart/gnome-keyring-secrets.desktop:150:NoDisplay=true
/etc/xdg/autostart/gnome-keyring-secrets.desktop:151:X-GNOME-Autostart-Phase=PreDisplayServer

== rc.local ==
无 rc.local

== rc*.d 目录下的启动脚本 ==
/etc/rc0.d:
total 0
lrwxrwxrwx 1 root root 20 May 13 08:06 K01alsa-utils -> ../init.d/alsa-utils
lrwxrwxrwx 1 root root 19 May 13 08:07 K01bluetooth -> ../init.d/bluetooth
lrwxrwxrwx 1 root root 22 May 13 08:10 K01cups-browsed -> ../init.d/cups-browsed
lrwxrwxrwx 1 root root 22 May 13 08:07 K01fake-hwclock -> ../init.d/fake-hwclock
lrwxrwxrwx 1 root root 13 May 13 08:10 K01fio -> ../init.d/fio
lrwxrwxrwx 1 root root 20 May 13 08:04 K01hwclock.sh -> ../init.d/hwclock.sh
lrwxrwxrwx 1 root root 17 May 13 08:08 K01lightdm -> ../init.d/lightdm
lrwxrwxrwx 1 root root 20 May 13 08:07 K01nfs-common -> ../init.d/nfs-common
lrwxrwxrwx 1 root root 18 May 13 08:09 K01plymouth -> ../init.d/plymouth
lrwxrwxrwx 1 root root 37 May 13 08:10 K01pulseaudio-enable-autospawn -> ../init.d/pulseaudio-enable-autospawn
lrwxrwxrwx 1 root root 17 May 13 08:07 K01rpcbind -> ../init.d/rpcbind
lrwxrwxrwx 1 root root 15 May 13 08:10 K01saned -> ../init.d/saned
lrwxrwxrwx 1 root root 22 May 13 08:06 K01triggerhappy -> ../init.d/triggerhappy
lrwxrwxrwx 1 root root 14 May 13 08:05 K01udev -> ../init.d/udev

/etc/rc1.d:
total 0
lrwxrwxrwx 1 root root 20 May 13 08:06 K01alsa-utils -> ../init.d/alsa-utils
lrwxrwxrwx 1 root root 19 May 13 08:07 K01bluetooth -> ../init.d/bluetooth
lrwxrwxrwx 1 root root 14 May 13 08:10 K01cups -> ../init.d/cups
lrwxrwxrwx 1 root root 22 May 13 08:10 K01cups-browsed -> ../init.d/cups-browsed
lrwxrwxrwx 1 root root 22 May 13 08:07 K01fake-hwclock -> ../init.d/fake-hwclock
lrwxrwxrwx 1 root root 13 May 13 08:10 K01fio -> ../init.d/fio
lrwxrwxrwx 1 root root 17 May 13 08:08 K01lightdm -> ../init.d/lightdm
lrwxrwxrwx 1 root root 20 May 13 08:07 K01nfs-common -> ../init.d/nfs-common
lrwxrwxrwx 1 root root 37 May 13 08:10 K01pulseaudio-enable-autospawn -> ../init.d/pulseaudio-enable-autospawn
lrwxrwxrwx 1 root root 15 May 13 08:10 K01saned -> ../init.d/saned
lrwxrwxrwx 1 root root 22 May 13 08:06 K01triggerhappy -> ../init.d/triggerhappy

/etc/rc2.d:
total 0
lrwxrwxrwx 1 root root 13 May 13 08:10 K01fio -> ../init.d/fio
lrwxrwxrwx 1 root root 19 May 13 08:07 S01bluetooth -> ../init.d/bluetooth
lrwxrwxrwx 1 root root 26 May 13 08:07 S01console-setup.sh -> ../init.d/console-setup.sh
lrwxrwxrwx 1 root root 14 May 13 08:05 S01cron -> ../init.d/cron
lrwxrwxrwx 1 root root 14 May 13 08:10 S01cups -> ../init.d/cups
lrwxrwxrwx 1 root root 22 May 13 08:10 S01cups-browsed -> ../init.d/cups-browsed
lrwxrwxrwx 1 root root 14 May 13 08:07 S01dbus -> ../init.d/dbus
lrwxrwxrwx 1 root root 24 May 13 08:07 S01dphys-swapfile -> ../init.d/dphys-swapfile
lrwxrwxrwx 1 root root 17 May 13 08:08 S01lightdm -> ../init.d/lightdm
lrwxrwxrwx 1 root root 18 May 13 08:09 S01plymouth -> ../init.d/plymouth
lrwxrwxrwx 1 root root 37 May 13 08:10 S01pulseaudio-enable-autospawn -> ../init.d/pulseaudio-enable-autospawn
lrwxrwxrwx 1 root root 15 May 13 08:05 S01rsync -> ../init.d/rsync
lrwxrwxrwx 1 root root 15 May 13 08:10 S01saned -> ../init.d/saned
lrwxrwxrwx 1 root root 13 May 13 08:07 S01ssh -> ../init.d/ssh
lrwxrwxrwx 1 root root 14 May 13 08:06 S01sudo -> ../init.d/sudo
lrwxrwxrwx 1 root root 22 May 13 08:06 S01triggerhappy -> ../init.d/triggerhappy

/etc/rc3.d:
total 0
lrwxrwxrwx 1 root root 13 May 13 08:10 K01fio -> ../init.d/fio
lrwxrwxrwx 1 root root 19 May 13 08:07 S01bluetooth -> ../init.d/bluetooth
lrwxrwxrwx 1 root root 26 May 13 08:07 S01console-setup.sh -> ../init.d/console-setup.sh
lrwxrwxrwx 1 root root 14 May 13 08:05 S01cron -> ../init.d/cron
lrwxrwxrwx 1 root root 14 May 13 08:10 S01cups -> ../init.d/cups
lrwxrwxrwx 1 root root 22 May 13 08:10 S01cups-browsed -> ../init.d/cups-browsed
lrwxrwxrwx 1 root root 14 May 13 08:07 S01dbus -> ../init.d/dbus
lrwxrwxrwx 1 root root 24 May 13 08:07 S01dphys-swapfile -> ../init.d/dphys-swapfile
lrwxrwxrwx 1 root root 17 May 13 08:08 S01lightdm -> ../init.d/lightdm
lrwxrwxrwx 1 root root 18 May 13 08:09 S01plymouth -> ../init.d/plymouth
lrwxrwxrwx 1 root root 37 May 13 08:10 S01pulseaudio-enable-autospawn -> ../init.d/pulseaudio-enable-autospawn
lrwxrwxrwx 1 root root 15 May 13 08:05 S01rsync -> ../init.d/rsync
lrwxrwxrwx 1 root root 15 May 13 08:10 S01saned -> ../init.d/saned
lrwxrwxrwx 1 root root 13 May 13 08:07 S01ssh -> ../init.d/ssh
lrwxrwxrwx 1 root root 14 May 13 08:06 S01sudo -> ../init.d/sudo
lrwxrwxrwx 1 root root 22 May 13 08:06 S01triggerhappy -> ../init.d/triggerhappy

/etc/rc4.d:
total 0
lrwxrwxrwx 1 root root 13 May 13 08:10 K01fio -> ../init.d/fio
lrwxrwxrwx 1 root root 19 May 13 08:07 S01bluetooth -> ../init.d/bluetooth
lrwxrwxrwx 1 root root 26 May 13 08:07 S01console-setup.sh -> ../init.d/console-setup.sh
lrwxrwxrwx 1 root root 14 May 13 08:05 S01cron -> ../init.d/cron
lrwxrwxrwx 1 root root 14 May 13 08:10 S01cups -> ../init.d/cups
lrwxrwxrwx 1 root root 22 May 13 08:10 S01cups-browsed -> ../init.d/cups-browsed
lrwxrwxrwx 1 root root 14 May 13 08:07 S01dbus -> ../init.d/dbus
lrwxrwxrwx 1 root root 24 May 13 08:07 S01dphys-swapfile -> ../init.d/dphys-swapfile
lrwxrwxrwx 1 root root 17 May 13 08:08 S01lightdm -> ../init.d/lightdm
lrwxrwxrwx 1 root root 18 May 13 08:09 S01plymouth -> ../init.d/plymouth
lrwxrwxrwx 1 root root 37 May 13 08:10 S01pulseaudio-enable-autospawn -> ../init.d/pulseaudio-enable-autospawn
lrwxrwxrwx 1 root root 15 May 13 08:05 S01rsync -> ../init.d/rsync
lrwxrwxrwx 1 root root 15 May 13 08:10 S01saned -> ../init.d/saned
lrwxrwxrwx 1 root root 13 May 13 08:07 S01ssh -> ../init.d/ssh
lrwxrwxrwx 1 root root 14 May 13 08:06 S01sudo -> ../init.d/sudo
lrwxrwxrwx 1 root root 22 May 13 08:06 S01triggerhappy -> ../init.d/triggerhappy

/etc/rc5.d:
total 0
lrwxrwxrwx 1 root root 13 May 13 08:10 K01fio -> ../init.d/fio
lrwxrwxrwx 1 root root 19 May 13 08:07 S01bluetooth -> ../init.d/bluetooth
lrwxrwxrwx 1 root root 26 May 13 08:07 S01console-setup.sh -> ../init.d/console-setup.sh
lrwxrwxrwx 1 root root 14 May 13 08:05 S01cron -> ../init.d/cron
lrwxrwxrwx 1 root root 14 May 13 08:10 S01cups -> ../init.d/cups
lrwxrwxrwx 1 root root 22 May 13 08:10 S01cups-browsed -> ../init.d/cups-browsed
lrwxrwxrwx 1 root root 14 May 13 08:07 S01dbus -> ../init.d/dbus
lrwxrwxrwx 1 root root 24 May 13 08:07 S01dphys-swapfile -> ../init.d/dphys-swapfile
lrwxrwxrwx 1 root root 17 May 13 08:08 S01lightdm -> ../init.d/lightdm
lrwxrwxrwx 1 root root 18 May 13 08:09 S01plymouth -> ../init.d/plymouth
lrwxrwxrwx 1 root root 37 May 13 08:10 S01pulseaudio-enable-autospawn -> ../init.d/pulseaudio-enable-autospawn
lrwxrwxrwx 1 root root 15 May 13 08:05 S01rsync -> ../init.d/rsync
lrwxrwxrwx 1 root root 15 May 13 08:10 S01saned -> ../init.d/saned
lrwxrwxrwx 1 root root 13 May 13 08:07 S01ssh -> ../init.d/ssh
lrwxrwxrwx 1 root root 14 May 13 08:06 S01sudo -> ../init.d/sudo
lrwxrwxrwx 1 root root 22 May 13 08:06 S01triggerhappy -> ../init.d/triggerhappy

/etc/rc6.d:
total 0
lrwxrwxrwx 1 root root 20 May 13 08:06 K01alsa-utils -> ../init.d/alsa-utils
lrwxrwxrwx 1 root root 19 May 13 08:07 K01bluetooth -> ../init.d/bluetooth
lrwxrwxrwx 1 root root 22 May 13 08:10 K01cups-browsed -> ../init.d/cups-browsed
lrwxrwxrwx 1 root root 22 May 13 08:07 K01fake-hwclock -> ../init.d/fake-hwclock
lrwxrwxrwx 1 root root 13 May 13 08:10 K01fio -> ../init.d/fio
lrwxrwxrwx 1 root root 20 May 13 08:04 K01hwclock.sh -> ../init.d/hwclock.sh
lrwxrwxrwx 1 root root 17 May 13 08:08 K01lightdm -> ../init.d/lightdm
lrwxrwxrwx 1 root root 20 May 13 08:07 K01nfs-common -> ../init.d/nfs-common
lrwxrwxrwx 1 root root 18 May 13 08:09 K01plymouth -> ../init.d/plymouth
lrwxrwxrwx 1 root root 37 May 13 08:10 K01pulseaudio-enable-autospawn -> ../init.d/pulseaudio-enable-autospawn
lrwxrwxrwx 1 root root 17 May 13 08:07 K01rpcbind -> ../init.d/rpcbind
lrwxrwxrwx 1 root root 15 May 13 08:10 K01saned -> ../init.d/saned
lrwxrwxrwx 1 root root 22 May 13 08:06 K01triggerhappy -> ../init.d/triggerhappy
lrwxrwxrwx 1 root root 14 May 13 08:05 K01udev -> ../init.d/udev

/etc/rcS.d:
total 0
lrwxrwxrwx 1 root root 20 May 13 08:04 K01hwclock.sh -> ../init.d/hwclock.sh
lrwxrwxrwx 1 root root 20 May 13 08:07 K01nfs-common -> ../init.d/nfs-common
lrwxrwxrwx 1 root root 17 May 13 08:07 K01rpcbind -> ../init.d/rpcbind
lrwxrwxrwx 1 root root 20 May 13 08:06 S01alsa-utils -> ../init.d/alsa-utils
lrwxrwxrwx 1 root root 18 May 13 08:05 S01apparmor -> ../init.d/apparmor
lrwxrwxrwx 1 root root 22 May 13 08:07 S01fake-hwclock -> ../init.d/fake-hwclock
lrwxrwxrwx 1 root root 27 May 13 08:07 S01keyboard-setup.sh -> ../init.d/keyboard-setup.sh
lrwxrwxrwx 1 root root 14 May 13 08:05 S01kmod -> ../init.d/kmod
lrwxrwxrwx 1 root root 22 May 13 08:09 S01plymouth-log -> ../init.d/plymouth-log
lrwxrwxrwx 1 root root 16 May 13 08:05 S01procps -> ../init.d/procps
lrwxrwxrwx 1 root root 14 May 13 08:05 S01udev -> ../init.d/udev
lrwxrwxrwx 1 root root 20 May 13 08:08 S01x11-common -> ../init.d/x11-common

## 第三方进程守护
无 pm2
无 supervisor
无 screen
无 tmux

## 设备占用（摄像头/音频）深度
== v4l2 设备（若装了 v4l-utils）==
bcm2835-codec-decode (platform:bcm2835-codec):
	/dev/video10
	/dev/video11
	/dev/video12
	/dev/video18
	/dev/video31

bcm2835-isp (platform:bcm2835-isp):
	/dev/video13
	/dev/video14
	/dev/video15
	/dev/video16
	/dev/video20
	/dev/video21
	/dev/video22
	/dev/video23
	/dev/media0
	/dev/media1

unicam (platform:fe801000.csi):
	/dev/video0
	/dev/media2

rpi-hevc-dec (platform:rpi-hevc-dec):
	/dev/video19
	/dev/media4

bcm2835-codec (vchiq:bcm2835-codec):
	/dev/media3


== 摄像头占用（lsof/fuser）==
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
   765   913   915   765   913   915   765   913   915   765   913   915   765   913   915
== ALSA 全局配置 ==
pcm.!default {
    type hw
    card 0
    device 0
}

ctl.!default {
    type hw
    card 0
}

pcm.i2s {
    type hw
    card 0
    device 0
    format S32_LE
    rate 48000
    channels 2
}
