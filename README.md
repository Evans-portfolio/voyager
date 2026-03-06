# Server Sorcery 101 - DevOps Infrastructure Project 🧙‍♂️

**Author:** Evans  
**Date:** February 2026  
**Project Duration:** January 2026 - February 2026  
**Status:** ✅ COMPLETE

## Project Overview 🎯

A multi-server virtualized infrastructure built from scratch to learn and demonstrate core DevOps skills including virtualization, Linux administration, networking, security hardening, load balancing, monitoring, and intrusion prevention.

**Key Achievement:** Production-grade infrastructure with 4 VMs, load balancing, real-time monitoring, and automated security protection.

## Infrastructure Architecture 🏗️

### Virtual Machines

| VM Name       | IP Address      | RAM  | CPU | Role              | Status |
|---------------|-----------------|------|-----|-------------------|--------|
| app-server    | 192.168.0.107   | 2GB  | 1   | Application Server| ✅ Active |
| web-server-1  | 192.168.0.113   | 1GB  | 1   | Web Server        | ✅ Active |
| web-server-2  | 192.168.0.114   | 1GB  | 1   | Web Server        | ✅ Active |
| load-balancer | 192.168.0.115   | 1GB  | 1   | Load Balancer     | ✅ Active |

### Network Configuration

- **Network Type:** Bridged Adapter
- **Subnet:** 192.168.0.0/24
- **Gateway:** 192.168.0.1
- **DNS Servers:** 192.168.0.1, 8.8.8.8
- **IP Assignment:** Static (configured via netplan)

### Technology Stack

- **Virtualization:** Oracle VirtualBox 7.x
- **Operating System:** Ubuntu Server 24.04 LTS
- **Web Server:** nginx
- **Load Balancer:** nginx (reverse proxy)
- **Monitoring:** Netdata
- **Security:** UFW, Fail2Ban, SSH keys
- **Host Machine:** macOS (24GB RAM, Quad-Core Intel i5)

## Deployed Services 🌐

| Service | Server(s) | Port | URL | Status |
|---------|-----------|------|-----|--------|
| nginx Web | web-server-1 | 80 | http://192.168.0.113 | ✅ Live |
| nginx Web | web-server-2 | 80 | http://192.168.0.114 | ✅ Live |
| nginx LB | load-balancer | 80 | http://192.168.0.115 | ✅ Live |
| Health Check | load-balancer | 80 | http://192.168.0.115/health | ✅ Live |
| Netdata | All VMs | 19999 | http://192.168.0.XXX:19999 | ✅ Live |
| Fail2Ban | All VMs | - | SSH Protection | ✅ Active |
| SSH | All VMs | 22 | ssh devops@192.168.0.XXX | ✅ Active |

## Security Implementation 🔒

### Authentication & Access

- ✅ **SSH Key Authentication:** Ed25519 key-based, password-less login
- ✅ **Password Authentication:** Disabled on all VMs
- ✅ **SSH Protocol:** Version 2 only
- ✅ **Authorized Users:** devops user only
- ✅ **Root Login:** Disabled via SSH

### Network Security

- ✅ **UFW Firewall:** Active on all VMs with default deny policy
- ✅ **Open Ports:**
  - SSH (22) - All VMs
  - HTTP (80) - web-server-1, web-server-2, load-balancer
  - Netdata (19999) - All VMs
- ✅ **Intrusion Prevention:** Fail2Ban monitoring SSH (5 failed attempts = 10 min ban)

### System Hardening

- ✅ **Secure Umask:** 027 (restrictive file permissions - files: 640, dirs: 750)
- ✅ **Automatic Security Updates:** Enabled via unattended-upgrades
- ✅ **Unused Services:** Disabled (bluetooth, cups, avahi)
- ✅ **Security Patches:** Automated nightly updates

## Network Topology 🌐
```
┌─────────────────────────────────────────────────────┐
│         Home Network (192.168.0.0/24)               │
│                                                     │
│  ┌─────────────┐                                    │
│  │   Router    │  192.168.0.1 (Gateway)             │
│  │   + DNS     │                                    │
│  └──────┬──────┘                                    │
│         │                                            │
│    ┌────┴────┬─────────┬─────────┐                │
│    │         │         │         │                  │
│  ┌─▼───┐  ┌─▼───┐  ┌─▼───┐  ┌─▼───┐             │
│  │ App │  │Web-1│  │Web-2│  │ LB  │             │
│  │ 107 │  │ 113 │  │ 114 │  │ 115 │             │
│  └─────┘  └─────┘  └─────┘  └──┬──┘             │
│                                  │                   │
│               Load Balancer      │                   │
│               Distributes ───────┤                   │
│               Traffic            │                   │
│                         ┌────────┴────────┐         │
│                         │                 │          │
│                      ┌──▼──┐          ┌──▼──┐      │
│                      │Web-1│          │Web-2│      │
│                      │ 113 │          │ 114 │      │
│                      └─────┘          └─────┘      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Access Instructions 🔑

### SSH Access from Host Machine
```bash
# Access any VM via SSH (no password required - uses SSH keys)
ssh devops@192.168.0.107  # app-server
ssh devops@192.168.0.113  # web-server-1
ssh devops@192.168.0.114  # web-server-2
ssh devops@192.168.0.115  # load-balancer
```

### Web Access
```bash
# Individual web servers
http://192.168.0.113  # Web Server 1
http://192.168.0.114  # Web Server 2

# Load balancer (automatically distributes to both)
http://192.168.0.115

# Health check endpoint
http://192.168.0.115/health
```

### Monitoring Dashboards
```bash
# Netdata real-time monitoring
http://192.168.0.107:19999  # app-server metrics
http://192.168.0.113:19999  # web-server-1 metrics
http://192.168.0.114:19999  # web-server-2 metrics
http://192.168.0.115:19999  # load-balancer metrics
```

### VirtualBox Console Access

1. Open VirtualBox Manager
2. Select desired VM
3. Click "Start" or "Show"
4. Login: `devops` / [your password]

## Build Process 🛠️

### Phase 1: VM Creation (Completed ✅)

1. Created app-server from Ubuntu Server 24.04 LTS ISO
2. Cloned app-server → web-server-1, web-server-2, load-balancer
   - Used "Full clone" with "Generate new MAC addresses"
3. Changed hostnames on each clone via `hostnamectl`
4. Verified network connectivity and unique IPs

**Time:** ~2 hours  
**Key Learning:** VM cloning best practices, MAC address management

### Phase 2: Network Configuration (Completed ✅)

1. Configured bridged networking on all VMs
2. Set static IP addresses via netplan
   - Created `/etc/netplan/50-cloud-init.yaml` configurations
   - Used `netplan try` for safe testing
3. Configured DNS (192.168.0.1, 8.8.8.8)
4. Verified inter-VM communication
5. Tested internet connectivity

**Time:** ~1 hour  
**Key Learning:** Netplan YAML syntax, static vs DHCP, DNS configuration

### Phase 3: Security Hardening (Completed ✅)

1. Generated Ed25519 SSH key pair on host machine
2. Deployed public key to all VMs via `ssh-copy-id`
3. Disabled password authentication in `/etc/ssh/sshd_config`
4. Configured UFW firewall (default deny, allow SSH)
5. Set secure umask (027) in `/etc/profile` and `/etc/bash.bashrc`
6. Enabled automatic security updates via `unattended-upgrades`
7. Disabled unnecessary services (bluetooth, cups)

**Time:** ~2 hours  
**Key Learning:** SSH key cryptography, firewall policies, security layers

### Phase 4: Server Roles (Completed ✅)

1. Installed nginx on web-server-1 and web-server-2
2. Created custom HTML pages for each web server
3. Configured nginx load balancer on load-balancer
   - Round-robin algorithm
   - Upstream backend configuration
4. Implemented health checks:
   - `max_fails=3` - Mark down after 3 failures
   - `fail_timeout=30s` - Retry after 30 seconds
   - Connection timeouts (5s)
5. Opened firewall port 80 for HTTP traffic
6. Tested load balancing functionality

**Time:** ~1.5 hours  
**Key Learning:** nginx configuration, load balancing algorithms, health checks

**Services Deployed:**
- nginx web servers on web-server-1 and web-server-2
- nginx load balancer on load-balancer
- Custom HTML pages served from both web servers
- Load balancer distributing traffic via round-robin algorithm

### Phase 5: Bonus Features (Completed ✅)

**Monitoring (Netdata):**
- Installed on all 4 VMs
- Configured to bind to all interfaces (0.0.0.0)
- Opened firewall port 19999
- Real-time dashboards accessible

**Time:** ~40 minutes

**Intrusion Prevention (Fail2Ban):**
- Installed on all 4 VMs
- Configured SSH jail protection
- Settings: 5 max attempts, 10 min ban time
- Automatic IP blocking for brute-force attacks

**Time:** ~30 minutes

**VPN (WireGuard):**
- VPN server configured on load-balancer (192.168.0.115)
- VPN network: 10.0.0.0/24, server IP: 10.0.0.1
- Port: 51820/udp
- Encryption: ChaCha20-Poly1305

**Time:** ~45 minutes

## Bonus Features Implemented ✅

### 1. Monitoring - Netdata ✅

**Status:** Operational on all 4 VMs

**Features:**
- Real-time CPU, memory, disk, network monitoring
- Per-second granularity metrics
- Beautiful web-based dashboards
- Zero configuration required
- Auto-detection of services

**Access:** 
- app-server: http://192.168.0.107:19999
- web-server-1: http://192.168.0.113:19999
- web-server-2: http://192.168.0.114:19999
- load-balancer: http://192.168.0.115:19999

**Configuration:**
- Bind address: `0.0.0.0` (all interfaces)
- Port: 19999
- Firewall: UFW rule added

---

### 2. Intrusion Prevention - Fail2Ban ✅

**Status:** Active on all 4 VMs protecting SSH

**Configuration:**
```ini
[DEFAULT]
bantime = 10m      # Ban duration
findtime = 10m     # Time window for counting failures
maxretry = 5       # Max failed attempts before ban

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
```

**Protection:**
- Monitors SSH login attempts in real-time
- Automatically bans IPs after 5 failed attempts
- Ban duration: 10 minutes
- Protects against brute-force attacks

**Verification:**
```bash
sudo fail2ban-client status sshd
```

---

### 3. Load Balancer Health Checks ✅

**Status:** Operational

**Algorithm:** Round-robin with automatic failover

**Health Check Configuration:**
```nginx
upstream web_backend {
    server 192.168.0.113 max_fails=3 fail_timeout=30s;
    server 192.168.0.114 max_fails=3 fail_timeout=30s;
}

# Connection timeouts
proxy_connect_timeout 5s;
proxy_send_timeout 5s;
proxy_read_timeout 5s;
```

**Features:**
- Automatic detection of failed backend servers
- Removes unhealthy servers from rotation
- Re-adds servers after 30 second timeout
- Health endpoint: http://192.168.0.115/health

**Testing:**
- Verified round-robin distribution
- Tested automatic failover when server is down
- Confirmed traffic only routes to healthy servers

---

### 4. VPN - WireGuard ✅

**Status:** Operational

**Implementation:**
- **VPN Server:** load-balancer (192.168.0.115)
- **VPN Protocol:** WireGuard (modern, fast, secure)
- **VPN Network:** 10.0.0.0/24
- **Server VPN IP:** 10.0.0.1
- **Client VPN IP:** 10.0.0.2
- **Port:** 51820/udp
- **Encryption:** ChaCha20-Poly1305 (authenticated encryption)

**Features:**
- Secure remote access to the internal network
- Firewall rule added for UDP port 51820
- Peer-based key exchange (no passwords)

---

## Key Learnings 🎓

### Technical Skills Acquired

- **Virtualization:** VirtualBox VM management, cloning, resource allocation
- **Linux Administration:** Ubuntu Server, user management, service configuration
- **Networking:** Static IPs, DNS, gateway configuration, subnets (/24), bridged vs NAT
- **SSH:** Key-based authentication, Ed25519 keys, secure configuration
- **Firewalls:** UFW configuration, default deny policies, port management
- **Web Servers:** nginx installation, configuration, virtual hosts
- **Load Balancing:** nginx reverse proxy, upstream backends, health checks, round-robin
- **Monitoring:** Netdata installation, dashboard access, real-time metrics
- **Security:** Fail2Ban, intrusion detection, automatic banning
- **Security Hardening:** umask, automatic updates, service management

### DevOps Concepts Understood

- **Infrastructure as Code Principles:** Repeatable configurations
- **Defense in Depth:** Multiple security layers (SSH keys + firewall + Fail2Ban)
- **High Availability:** Load balancing, health checks, automatic failover
- **Monitoring & Observability:** Real-time metrics, dashboard visualization
- **Automation:** Automatic security updates, automatic failover
- **Default Deny Policies:** Firewall and security best practices
- **Documentation Importance:** Clear documentation for reproducibility

### Networking Deep Dive

**Concepts Mastered:**
- **DNS:** Domain Name System translates names to IPs
- **Gateway:** Router connecting local network to internet (192.168.0.1)
- **Subnet:** Network range defining which IPs can communicate directly (/24 = 192.168.0.1-254)
- **localhost (127.0.0.1):** Local-only interface
- **0.0.0.0:** All interfaces (network-accessible)
- **Static vs DHCP:** Permanent IPs vs dynamic assignment
- **Ports:** Service endpoints (22=SSH, 80=HTTP, 19999=Netdata)

## Troubleshooting Notes 🔧

### Issues Encountered & Solutions

**Issue 1: Ubuntu Installation Hanging**
- **Problem:** Installation stuck at "curtin command in-target" during package download
- **Cause:** Network timeout during installation
- **Solution:** Disabled network adapter during installation, enabled after first boot
- **Learning:** Offline installation is faster and more reliable

**Issue 2: Network Not Working After Clone**
- **Problem:** Cloned VMs showing NO-CARRIER on network interface
- **Cause:** "Cable Connected" checkbox unchecked in VirtualBox
- **Solution:** Enabled "Cable Connected" in Network settings
- **Learning:** VirtualBox network adapter has virtual "cable" that can be disconnected

**Issue 3: Static IP Configuration YAML Syntax**
- **Problem:** netplan configuration errors due to indentation
- **Cause:** YAML is whitespace-sensitive, used tabs instead of spaces
- **Solution:** Used exactly 2 spaces for each indentation level
- **Learning:** Always use `netplan try` to test before applying permanently

**Issue 4: Netdata Not Accessible from Browser**
- **Problem:** Netdata installed but http://IP:19999 connection refused
- **Cause:** Netdata bound to 127.0.0.1 (localhost only), not 0.0.0.0
- **Solution:** Configured `bind to = *` in `/etc/netplan/netdata.conf`
- **Learning:** Services often default to localhost for security - must explicitly expose to network

**Issue 5: nginx Configuration Errors**
- **Problem:** nginx test failing with "unexpected end of file"
- **Cause:** Accidentally pasted text/comments into config file, missing closing braces
- **Solution:** Deleted file and recreated with clean configuration
- **Learning:** Config files must be exact - extra characters cause failures

## Future Enhancements 🚀

**Potential Next Steps:**

- [ ] Deploy real application on app-server (Node.js/Python/Go)
- [ ] Connect web servers to app-server backend
- [ ] Implement HTTPS with SSL/TLS certificates (Let's Encrypt)
- [ ] Add database server (PostgreSQL/MySQL)
- [x] Set up VPN (WireGuard) for secure remote access
- [ ] Implement CI/CD pipeline (GitHub Actions → automated deployment)
- [ ] Add centralized logging (ELK stack)
- [ ] Create backup/restore procedures
- [ ] Implement Infrastructure as Code (Terraform/Ansible)
- [ ] Migrate to cloud platform (AWS EC2, Azure VMs)

## Project Files 📁
```
ServerSorcery101/
├── README.md (this file)
├── documentation/
│   ├── network-configs/
│   │   └── netplan-static-ip.yaml
│   ├── security/
│   │   ├── fail2ban-jail.local
│   │   └── sshd-config-secure.conf
│   └── nginx/
│       └── load-balancer-config.conf
└── screenshots/
    ├── netdata-dashboard.png
    ├── load-balancer-test.png
    └── fail2ban-status.png
```

## Screenshots 📸

### Netdata Monitoring Dashboard
*Real-time system monitoring showing CPU, memory, disk I/O, and network metrics with per-second granularity*

### Load Balancer in Action
*Terminal output showing curl requests alternating between web-server-1 and web-server-2, demonstrating round-robin distribution*

### Fail2Ban Protection Status
*Fail2Ban client status showing SSH jail active and protecting all servers from brute-force attacks*

## References & Resources 📚

### Official Documentation
- [Ubuntu Server Documentation](https://ubuntu.com/server/docs)
- [VirtualBox Documentation](https://www.virtualbox.org/manual/)
- [nginx Documentation](https://nginx.org/en/docs/)
- [Netdata Documentation](https://learn.netdata.cloud/)
- [Fail2Ban Documentation](https://www.fail2ban.org/)

### Tutorials & Guides
- [UFW Essentials](https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands)
- [SSH Key Management](https://www.ssh.com/academy/ssh/keygen)
- [nginx Load Balancing](https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/)
- [Linux Security Hardening](https://www.cyberciti.biz/tips/linux-security.html)

### Learning Resources
- Netplan Configuration Examples
- DigitalOcean Community Tutorials
- Ubuntu Server Guide
- nginx Admin Guide

## Technical Specifications Summary 📊

**Total Infrastructure:**
- VMs: 4
- Total RAM: 5GB
- Total CPU cores: 4
- Total Storage: 80GB

**Services Running:**
- Web servers: 2
- Load balancer: 1
- Monitoring instances: 4
- Intrusion prevention: 4
- SSH servers: 4

**Network:**
- Static IPs: 4
- Ports exposed: 3 types (22, 80, 19999)
- Firewall rules: 12+ (3 per VM)

**Security Layers:**
- SSH key authentication
- Password auth disabled
- UFW firewall (default deny)
- Fail2Ban intrusion prevention
- Automatic security updates
- Secure file permissions (umask 027)

## Acknowledgments 🙏

This project was completed as part of learning DevOps fundamentals through the "Server Sorcery 101" curriculum, with focus on practical, hands-on experience building production-grade infrastructure.

**Key Focus Areas:**
- Learning by doing (manual configuration before automation)
- Understanding the "why" behind each decision
- Building real, working infrastructure (not just tutorials)
- Professional documentation practices
- Problem-solving and troubleshooting skills

---

## Project Status

**Completion Date:** February 2026  
**Project Status:** ✅ COMPLETE  
**Core Requirements:** 100% Complete  
**Bonus Challenges:** 100% Complete (3 out of 3)

### What's Working:
- ✅ 4 fully secured VMs with SSH key authentication
- ✅ 2 web servers serving HTTP traffic with custom pages
- ✅ 1 load balancer distributing traffic with health checks
- ✅ Real-time monitoring on all 4 VMs (Netdata)
- ✅ Intrusion prevention on all 4 VMs (Fail2Ban)
- ✅ Static IP networking with proper DNS/gateway configuration
- ✅ Production-grade security implementation
- ✅ Comprehensive documentation

### Skills Demonstrated:
- Virtualization & VM management
- Linux system administration
- Network configuration & troubleshooting
- Security hardening & best practices
- Load balancing & high availability
- Monitoring & observability
- Service configuration (nginx, Fail2Ban, Netdata)
- Technical documentation

**Next Learning Path:** Docker containerization, Cloud platforms (AWS/Azure), Infrastructure as Code (Terraform)

---

