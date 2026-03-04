# Linux Command Cheat Sheet - One Sheet, Every Distro

## Part 1: Universal Commands (All Distros)

### File & Directory Operations

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `ls` | `$ ls -la`<br>`drwxr-xr-x 3 user user 4096 Feb 16 10:00 .`<br>`-rw-r--r-- 1 user user  220 Feb 15 09:30 .bash_logout` | List directory contents, check permissions | View file details, hidden files, and access rights essential for security auditing |
| `cd` | `$ cd /var/log && pwd`<br>`/var/log` | Navigate filesystem hierarchy | Change working directory to access files in different locations |
| `pwd` | `$ pwd`<br>`/home/user/projects` | Confirm current location | Essential in scripts and when navigating deep directory trees |
| `cp` | `$ cp -r project/ backup/`<br>`$ ls backup/`<br>`project/` | Copy files or directories | Backup data, duplicate configurations, or deploy files to new locations |
| `mv` | `$ mv oldname.txt newname.txt` | Rename or move files | Organize files, rename versions, or relocate data without duplication |
| `rm` | `$ rm -i important.txt`<br>`rm: remove regular file 'important.txt'? y` | Delete files permanently | Free space, but `-i` flag prevents accidental deletion |
| `mkdir` | `$ mkdir -p projects/{dev,test,prod}` | Create directory structures | `-p` creates parent directories, enabling complex tree creation in one command |
| `find` | `$ find /var/log -name "*.log" -mtime +7`<br>`/var/log/nginx/access.log.1` | Locate files by criteria | Essential for log rotation, cleanup scripts, and system maintenance |
| `touch` | `$ touch -t 202402151200 report.txt` | Create empty files or update timestamps | Trigger rebuilds in makefiles, create placeholders, or force backup syncs |

### File Viewing & Manipulation

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `cat` | `$ cat /etc/os-release`<br>`PRETTY_NAME="Ubuntu 22.04.4 LTS"` | View entire file content | Quick inspection of small configuration files |
| `less` | `$ less /var/log/syslog`<br>`(arrow keys to scroll, q to quit)` | View large files interactively | Memory-efficient for multi-GB logs; searchable with `/pattern` |
| `head` | `$ head -n 5 /etc/passwd`<br>`root:x:0:0:root:/root:/bin/bash` | Preview file beginning | Check file format, view recent log entries, or sample data |
| `tail` | `$ tail -f /var/log/nginx/error.log`<br>`2024/02/16 10:15:30 [error] ...` | Monitor file changes in real-time | Critical for live debugging; `-f` follows new entries as they arrive |
| `grep` | `$ grep -r "ERROR" /var/log/`<br>`/var/log/app.log:ERROR: Connection failed` | Search text patterns | Filter logs, find configuration settings, or audit code |
| `awk` | `$ awk '{print $1}' access.log \| sort \| uniq -c \| sort -rn` | Process structured text data | Extract columns, calculate sums, generate reports from logs |
| `sed` | `$ sed -i 's/old_ip/192.168.1.1/g' config.txt` | Stream editing, find/replace | Batch modify configurations without opening editors |
| `tar` | `$ tar -czvf backup.tar.gz /etc/nginx/`<br>`/etc/nginx/nginx.conf` | Archive and compress directories | Create portable backups; `-czvf` = create, gzip, verbose, file |
| `chmod` | `$ chmod 750 script.sh`<br>`$ ls -l script.sh`<br>`-rwxr-x--- 1 user group` | Modify file permissions | Secure files by restricting read/write/execute access |
| `chown` | `$ sudo chown www-data:www-data /var/www/html` | Change file ownership | Ensure services can access their files (web servers, databases) |

### Process Management

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `ps` | `$ ps aux \| grep nginx`<br>`www-data  1234  0.0  0.1  ... nginx: worker process` | Snapshot of running processes | Identify process IDs, resource usage, and command details |
| `top` | `$ top`<br>`%Cpu(s): 15.3 us,  4.2 sy,  0.0 ni` | Interactive process viewer | Real-time system monitoring; sort by CPU/memory usage |
| `htop` | `$ htop`<br>`(colorful interactive interface)` | Enhanced process viewer | Visual tree view, kill processes with F9, search with F3 |
| `kill` | `$ kill -9 1234` | Terminate misbehaving processes | `-9` (SIGKILL) forces termination when graceful shutdown fails |
| `killall` | `$ killall -u username firefox` | Kill processes by name | Terminate all instances of an application efficiently |
| `nice` | `$ nice -n 10 ./backup-script.sh` | Adjust process priority | Lower priority for background tasks to preserve system responsiveness |
| `nohup` | `$ nohup python server.py &`<br>`[1] 5678`<br>`appending output to nohup.out` | Run command immune to hangups | Keep processes running after SSH logout |
| `jobs` | `$ jobs`<br>`[1]+  Running                 nohup python server.py &` | List background jobs | Manage suspended or background tasks in current shell |
| `fg` | `$ fg %1`<br>`python server.py` | Bring background job to foreground | Resume interactive control of background processes |
| `bg` | `$ bg %1`<br>`[1]+ python server.py &` | Resume suspended job in background | Continue execution without blocking terminal |

### System Information & Monitoring

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `df` | `$ df -h`<br>`/dev/sda1       98G   45G   48G  49% /` | Check disk space usage | Prevent disk-full outages; `-h` shows human-readable sizes |
| `du` | `$ du -sh /var/log/`<br>`2.3G    /var/log/` | Check directory sizes | Identify space hogs; `-s` summarizes, `-h` humanizes |
| `free` | `$ free -h`<br>`Mem: 15Gi 8.2Gi 2.1Gi 4.7Gi` | Display memory usage | Monitor RAM availability; `-h` for readable output |
| `uptime` | `$ uptime`<br>`10:30:00 up 15 days, 4:25, 2 users, load average: 0.52` | Check system load | Assess system stability; load average > CPU count indicates overload |
| `uname` | `$ uname -a`<br>`Linux server 5.15.0-91-generic #101-Ubuntu` | Display kernel information | Verify OS version for compatibility and security patches |
| `lscpu` | `$ lscpu \| grep "CPU(s):"`<br>`CPU(s):              8` | Display CPU architecture | Plan workload distribution, check virtualization support |
| `lsblk` | `$ lsblk`<br>`NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT`<br>`sda      8:0    0  100G  0 disk` | List block devices | Identify disks and partitions before mounting or formatting |
| `dmesg` | `$ dmesg \| grep -i error` | Kernel ring buffer messages | Debug hardware issues, driver problems, boot failures |
| `vmstat` | `$ vmstat 1 5`<br>`procs -----------memory----------`<br>` r  b   swpd   free   buff  cache` | Virtual memory statistics | Diagnose memory pressure, swap usage, I/O bottlenecks |
| `iostat` | `$ iostat -x 1 3` | CPU and I/O statistics | Identify disk I/O bottlenecks affecting application performance |
| `netstat` | `$ netstat -tulpn \| grep :80`<br>`tcp   0   0 0.0.0.0:80   0.0.0.0:*   LISTEN   1234/nginx` | Network connections and ports | Verify services listening, diagnose connection issues |
| `ss` | `$ ss -tulnp` | Socket statistics | Faster, modern replacement for netstat; essential for network debugging |
| `lsof` | `$ lsof -i :8080`<br>`java   2345  user  50u  IPv6  ...  TCP *:8080 (LISTEN)` | List open files and processes | Find which process uses a port or holds a file open |

### User & Permission Management

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `whoami` | `$ whoami`<br>`deployuser` | Confirm current user identity | Essential in scripts to verify execution context |
| `id` | `$ id`<br>`uid=1000(user) gid=1000(user) groups=1000(user),4(adm),24(cdrom)` | Display user/group IDs | Troubleshoot permission issues, verify group memberships |
| `sudo` | `$ sudo systemctl restart nginx`<br>`[sudo] password for user:` | Execute commands as superuser | Perform administrative tasks without logging in as root |
| `su` | `$ su - postgres`<br>`Password:` | Switch to another user account | `-` loads user's environment; essential for database administration |
| `passwd` | `$ passwd`<br>`Changing password for user.`<br>`Current password:` | Change user password | Security maintenance, compliance requirements |
| `useradd` | `$ sudo useradd -m -s /bin/bash developer` | Create new user account | `-m` creates home directory, `-s` sets shell for new employees |
| `usermod` | `$ sudo usermod -aG docker deployuser` | Modify user attributes | `-aG` appends to group; grants Docker access without removing other groups |
| `groups` | `$ groups deployuser`<br>`deployuser : deployuser docker sudo` | List user group memberships | Verify access rights for shared resources |
| `chpasswd` | `$ echo "user:newpass" \| sudo chpasswd` | Bulk password updates | Script password changes across multiple accounts |

### Network Operations

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `ping` | `$ ping -c 4 google.com`<br>`PING google.com (142.250.80.46) 56(84) bytes`<br>`64 bytes from ...: icmp_seq=1 ttl=117 time=15.3 ms` | Test network connectivity | Verify DNS resolution and network reachability |
| `curl` | `$ curl -I https://api.example.com`<br>`HTTP/2 200`<br>`content-type: application/json` | Transfer data with URLs | Test APIs, download files, check headers; `-I` for headers only |
| `wget` | `$ wget -O backup.sql https://db.example.com/backup` | Download files from web | Resume interrupted downloads with `-c`, recursive downloads |
| `scp` | `$ scp file.txt user@server:/home/user/` | Secure file copy between hosts | Transfer files over SSH without separate FTP setup |
| `rsync` | `$ rsync -avz --delete /local/ user@remote:/backup/` | Synchronize files/directories | Efficient incremental backups; `-a` archive, `-z` compress, `--delete` sync deletions |
| `ssh` | `$ ssh -i key.pem user@ec2-54-123.compute.amazonaws.com` | Secure remote login | Encrypted remote administration, tunneling, command execution |
| `ssh-keygen` | `$ ssh-keygen -t ed25519 -C "deploy@company.com"` | Generate SSH key pairs | Create authentication credentials for passwordless login |
| `ssh-copy-id` | `$ ssh-copy-id -i ~/.ssh/id_rsa.pub user@server` | Install public key on server | Automate key distribution for passwordless authentication |
| `ifconfig` / `ip` | `$ ip addr show`<br>`2: eth0: <BROADCAST,MULTICAST> mtu 1500`<br>`inet 192.168.1.100/24 brd 192.168.1.255` | Network interface configuration | Modern `ip` replaces `ifconfig`; configure IPs, routes, interfaces |
| `traceroute` | `$ traceroute google.com`<br>`1  192.168.1.1 (192.168.1.1)  2.1 ms`<br>`2  10.0.0.1 (10.0.0.1)  5.4 ms` | Trace network path | Diagnose routing issues, identify network hops and latency |
| `nslookup` / `dig` | `$ dig +short google.com`<br>`142.250.80.46` | DNS lookup | `dig` provides detailed DNS debugging; troubleshoot resolution failures |
| `nc` (netcat) | `$ nc -zv db.server 5432`<br>`Connection to db.server 5432 port [tcp/postgresql] succeeded!` | Network debugging swiss-army knife | Test port connectivity, create simple servers, transfer data |
| `tcpdump` | `$ sudo tcpdump -i eth0 port 80 -w capture.pcap` | Packet analyzer | Capture network traffic for security analysis or debugging |

### Text Processing & Pipelines

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `sort` | `$ sort -t: -k3 -n /etc/passwd` | Sort lines by criteria | Organize data; `-t` delimiter, `-k` key, `-n` numeric sort |
| `uniq` | `$ sort file.txt \| uniq -c` | Filter duplicate lines | `-c` counts occurrences; essential for log analysis |
| `wc` | `$ wc -l /var/log/syslog`<br>`15234 /var/log/syslog` | Count lines, words, bytes | Quantify log volume, file sizes; `-l` for line count |
| `cut` | `$ cut -d: -f1 /etc/passwd` | Extract columns from lines | Parse delimited data; `-d` delimiter, `-f` fields |
| `paste` | `$ paste file1.txt file2.txt` | Merge lines of files | Combine columns from separate files side-by-side |
| `tr` | `$ echo "hello" \| tr 'a-z' 'A-Z'`<br>`HELLO` | Translate/delete characters | Case conversion, character substitution, squeeze repeats |
| `tee` | `$ command \| tee output.log` | Read from stdin, write to stdout and files | View output and save to file simultaneously |
| `xargs` | `$ find . -name "*.log" \| xargs rm` | Build and execute commands from stdin | Handle large argument lists, parallel execution with `-P` |
| `diff` | `$ diff -u config.old config.new` | Compare files line by line | Identify configuration changes, verify deployments |
| `comm` | `$ comm -12 file1.sorted file2.sorted` | Compare two sorted files line by line | Find common lines or unique entries between datasets |

### Compression & Archiving

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `gzip` | `$ gzip -k large.log`<br>`$ ls -lh large.log.gz`<br>`-rw-r--r-- 1 user user 2.1M Feb 16 10:00 large.log.gz` | Compress single files | Standard compression; `-k` keeps original; good for logs |
| `gunzip` | `$ gunzip large.log.gz` | Decompress .gz files | Restore compressed files to original state |
| `bzip2` | `$ bzip2 -k backup.sql` | Higher compression than gzip | Better compression ratio, slower speed; use for archives |
| `xz` | `$ xz -k database.dump` | Maximum compression | Best ratio, slowest; ideal for long-term storage |
| `zip` | `$ zip -r project.zip project/ -x "*.git*"` | Create ZIP archives | Cross-platform compatibility; exclude patterns with `-x` |
| `unzip` | `$ unzip -l archive.zip`<br>`Archive: archive.zip`<br>`Length      Date    Time    Name`<br>`---------  ---------- -----   ----`<br>`     1524  2024-02-15 10:30   file.txt` | List/extract ZIP contents | Preview contents with `-l` before extraction |

---

## Part 2: Distro-Specific Commands

### Debian/Ubuntu (APT-based)

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `apt update` | `$ sudo apt update`<br>`Hit:1 http://archive.ubuntu.com jammy InRelease`<br>`Reading package lists... Done` | Refresh package database | Essential before installing software to get latest versions |
| `apt upgrade` | `$ sudo apt upgrade -y`<br>`0 upgraded, 0 newly installed, 0 to remove` | Upgrade installed packages | Security patches and bug fixes; `-y` auto-confirms |
| `apt install` | `$ sudo apt install nginx`<br>`The following NEW packages will be installed:`<br>`nginx-common nginx-core` | Install software packages | Primary software installation method; handles dependencies |
| `apt remove` | `$ sudo apt remove --purge nginx` | Remove packages | `--purge` deletes config files; clean uninstallation |
| `apt search` | `$ apt search python3-dev`<br>`Sorting... Done`<br>`Full Text Search... Done`<br>`python3-dev/jammy 3.10.6-1 amd64` | Find packages | Locate correct package names before installation |
| `apt show` | `$ apt show nginx \| grep Version`<br>`Version: 1.18.0-6ubuntu14.4` | Display package details | Verify versions, dependencies, and descriptions |
| `apt autoremove` | `$ sudo apt autoremove`<br>`The following packages will be REMOVED:`<br>`0 upgraded, 0 newly installed, 5 to remove` | Clean unused dependencies | Free disk space by removing orphaned packages |
| `dpkg` | `$ dpkg -l \| grep nginx`<br>`ii  nginx  1.18.0-6ubuntu14.4  amd64` | Low-level package management | Query installed packages, install .deb files directly |
| `add-apt-repository` | `$ sudo add-apt-repository ppa:ondrej/php` | Add third-party repositories | Access newer software versions not in official repos |

### RHEL/CentOS/Fedora/Rocky Linux (YUM/DNF/RPM-based)

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `dnf update` | `$ sudo dnf update -y`<br>`Complete!` | Update all packages | Modern replacement for yum; faster dependency resolution |
| `dnf install` | `$ sudo dnf install httpd`<br>`Installed:`<br>`httpd-2.4.57-5.el9.x86_64` | Install packages | Primary installation method on RHEL 8+ and Fedora |
| `dnf remove` | `$ sudo dnf remove httpd` | Remove packages | Clean uninstallation with dependency cleanup |
| `dnf search` | `$ dnf search nginx`<br>`Last metadata expiration check: 0:05:21 ago`<br>`nginx.x86_64 : A high performance web server` | Find packages | Discover available software and descriptions |
| `dnf info` | `$ dnf info httpd`<br>`Name         : httpd`<br>`Version      : 2.4.57`<br>`Release      : 5.el9` | Show package details | Verify version, repository source, dependencies |
| `yum` (legacy) | `$ sudo yum install vim` | Install on older systems | Still works on RHEL 7; being phased out for dnf |
| `rpm` | `$ rpm -qa \| grep httpd`<br>`httpd-2.4.57-5.el9.x86_64` | Query RPM database | Low-level package management; install .rpm files with `-i` |
| `rpm -ql` | `$ rpm -ql httpd`<br>`/etc/httpd/conf/httpd.conf`<br>`/usr/sbin/httpd` | List package files | Find where package installed its files |
| `subscription-manager` | `$ sudo subscription-manager register --username user` | RHEL subscription mgmt | Required for RHEL updates; manage entitlements |

### Arch Linux / Manjaro (Pacman-based)

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `pacman -Syu` | `$ sudo pacman -Syu`<br>`:: Synchronizing package databases...`<br>`:: Starting full system upgrade...` | Sync and upgrade system | Single command for full system update; `-S` sync, `-y` refresh, `-u` upgrade |
| `pacman -S` | `$ sudo pacman -S nginx`<br>`resolving dependencies...`<br>`looking for conflicting packages...` | Install packages | Install from official repositories with dependency resolution |
| `pacman -R` | `$ sudo pacman -Rns nginx` | Remove packages | `-R` remove, `-n` configs, `-s` unused deps (complete cleanup) |
| `pacman -Ss` | `$ pacman -Ss docker`<br>`community/docker 1:24.0.7-1`<br>`Packager, runtime and...` | Search packages | Find packages in repos with descriptions |
| `pacman -Qi` | `$ pacman -Qi nginx`<br>`Name            : nginx`<br>`Version         : 1.24.0-2` | Query installed package | Detailed info about installed packages |
| `pacman -Ql` | `$ pacman -Ql nginx` | List package files | See every file installed by a package |
| `pacman -Sc` | `$ sudo pacman -Sc` | Clean package cache | Free space by removing old package versions from cache |
| `yay` (AUR helper) | `$ yay -S google-chrome`<br>`:: Checking for conflicts...`<br>`:: Checking for inner conflicts...` | Install from AUR | Access community packages not in official repos |

### openSUSE (Zypper-based)

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `zypper refresh` | `$ sudo zypper ref`<br>`Repository 'Main Repository' is up to date.` | Refresh repositories | Update package metadata before operations |
| `zypper update` | `$ sudo zypper up` | Update installed packages | Standard system maintenance |
| `zypper install` | `$ sudo zypper in nginx` | Install packages | Clean syntax: `in` = install |
| `zypper search` | `$ zypper se docker`<br>`S \| Name      │ Summary`<br>`--+-------------------+`<br>`  | docker │ ...` | Search packages | Table output with status indicators |
| `zypper info` | `$ zypper if nginx` | Show package info | `if` = info; detailed metadata |
| `zypper dist-upgrade` | `$ sudo zypper dup` | Distribution upgrade | Major version upgrades; handles repo changes |

### Alpine Linux (APK-based)

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `apk update` | `$ sudo apk update`<br>`fetch https://dl-cdn.alpinelinux.org/...`<br>`OK: 15000 distinct packages available` | Update package index | Essential before installing in container environments |
| `apk add` | `$ sudo apk add nginx`<br>`(1/3) Installing pcre (8.45-r2)`<br>`(2/3) Installing nginx (1.24.0-r6)` | Install packages | Common in Docker containers; very fast |
| `apk del` | `$ sudo apk del nginx` | Remove packages | Clean removal with dependency cleanup |
| `apk search` | `$ apk search nginx`<br>`nginx-1.24.0-r6`<br>`nginx-mod-http-geoip2-1.24.0-r6` | Find packages | Discover available packages |
| `apk info` | `$ apk info -a nginx` | Show package details | `-a` shows all info including dependencies |

### Gentoo (Portage-based)

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `emerge --sync` | `$ sudo emerge --sync`<br>`>>> Syncing repository 'gentoo'...` | Sync Portage tree | Update package definitions (like apt update) |
| `emerge` | `$ sudo emerge www-servers/nginx` | Install packages | Source-based installation; compiles locally |
| `emerge --update` | `$ sudo emerge -uD @world` | Update system | `-u` update, `-D` deep, `@world` all packages |
| `emerge --search` | `$ emerge -s nginx` | Search packages | Find packages in Portage tree |
| `emerge --info` | `$ emerge -pv nginx` | Pretend/verbose install | `-p` pretend (show what would be done), `-v` verbose |
| `equery` | `$ equery f nginx` | Query package info | List files owned by package (from gentoolkit) |

---

## Quick Reference: When to Use What

| Task | Universal | Debian/Ubuntu | RHEL/Fedora | Arch | Alpine (Containers) |
|------|-----------|---------------|-------------|------|---------------------|
| **Update package list** | - | `apt update` | `dnf check-update` | `pacman -Sy` | `apk update` |
| **Upgrade all packages** | - | `apt upgrade` | `dnf update` | `pacman -Syu` | `apk upgrade` |
| **Install package** | compile from source | `apt install` | `dnf install` | `pacman -S` | `apk add` |
| **Remove package** | delete manually | `apt remove` | `dnf remove` | `pacman -R` | `apk del` |
| **Search packages** | - | `apt search` | `dnf search` | `pacman -Ss` | `apk search` |
| **Find file owner** | - | `dpkg -S file` | `rpm -qf file` | `pacman -Qo file` | `apk info --who-owns file` |

---

## Pro Tips

1. **Use `man` pages**: Every command has detailed documentation via `man command`
2. **Tab completion**: Press `Tab` twice to see available options
3. **History search**: `Ctrl+R` to search command history interactively
4. **Copy with progress**: `rsync -avh --progress source dest` for large transfers
5. **Safe deletion**: Always use `-i` (interactive) or test with `ls` first before `rm`
6. **Pipe to `less`**: Add `| less` to any command with long output for pagination