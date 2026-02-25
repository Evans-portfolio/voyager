# Server Sorcery 101 - DevOps Infrastructure Project 🧙‍♂️

**Author:** Evans 
**Date:** February 2026  
**Project Duration:** January - TBD

## Project Overview 🎯

A multi-server virtualized infrastructure built from scratch to learn and demonstrate core DevOps skills including virtualization, Linux administration, networking, and security hardening.

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
- **Host Machine:** macOS (24GB RAM, Quad-Core Intel i5)

## Security Implementation 🔒

### Authentication & Access

- ✅ **SSH Key Authentication:** Password-less login configured
- ✅ **Password Authentication:** Disabled on all VMs
- ✅ **SSH Protocol:** Version 2 only
- ✅ **Authorized Users:** devops user only

### Network Security

- ✅ **UFW Firewall:** Active on all VMs
- ✅ **Open Ports:** SSH (22) only (currently)
- ✅ **Default Policy:** Deny all incoming, allow outgoing

### System Hardening

- ✅ **Secure Umask:** 027 (restrictive file permissions)
- ✅ **Automatic Security Updates:** Enabled via unattended-upgrades
- ✅ **Unused Services:** Disabled (bluetooth, cups)
- ✅ **Root Login:** Disabled via SSH

## Access Instructions 🔑

### SSH Access from Host Machine
```bash
# Access any VM via SSH (no password required)
ssh devops@192.168.0.107  # app-server
ssh devops@192.168.0.113  # web-server-1
ssh devops@192.168.0.114  # web-server-2
ssh devops@192.168.0.115  # load-balancer
```

### VirtualBox Console Access

1. Open VirtualBox Manager
2. Select desired VM
3. Click "Start" or "Show"
4. Login: `devops` / [your password]

## Build Process 🛠️

### Phase 1: VM Creation (Completed ✅)

1. Created app-server from Ubuntu Server ISO
2. Cloned app-server → web-server-1, web-server-2, load-balancer
3. Changed hostnames on each clone
4. Verified network connectivity

### Phase 2: Network Configuration (Completed ✅)

1. Configured bridged networking on all VMs
2. Set static IP addresses via netplan
3. Verified inter-VM communication
4. Tested internet connectivity

### Phase 3: Security Hardening (Completed ✅)

1. Generated SSH key pair on host machine
2. Deployed public key to all VMs
3. Disabled password authentication
4. Configured UFW firewall (port 22 only)
5. Set secure umask (027)
6. Enabled automatic security updates
7. Disabled unnecessary services

### Phase 4: Server Roles (Planned 📅)

- [ ] Install nginx on web servers
- [ ] Configure load balancer (HAProxy/nginx)
- [ ] Deploy test application
- [ ] Implement health checks
- [ ] Test load balancing functionality

## Key Learnings 🎓

### Technical Skills Acquired

- Linux server installation and configuration
- Network configuration (static IPs, DNS, gateway, subnets)
- SSH key-based authentication
- Firewall configuration (UFW)
- VM cloning and templating
- Security hardening principles
- Remote server administration

### DevOps Concepts Understood

- Infrastructure as Code principles
- Defense in depth security
- Automation vs. manual configuration
- Default deny firewall policies
- The importance of documentation

## Troubleshooting Notes 🔧

### Issues Encountered & Solutions

**Issue 1: Ubuntu Installation Hanging**
- **Problem:** Installation stuck at "curtin command in-target"
- **Solution:** Disabled network during installation, enabled after first boot

**Issue 2: Network Not Working After Clone**
- **Problem:** Cloned VMs had network issues
- **Solution:** Ensured "Generate new MAC addresses" during clone process

**Issue 3: Static IP Configuration**
- **Challenge:** Understanding netplan YAML syntax
- **Solution:** Careful attention to indentation, used `netplan try` for safety

## Future Enhancements 🚀

- [ ] Install and configure web application
- [ ] Implement monitoring (Netdata/Prometheus)
- [ ] Set up VPN (WireGuard)
- [ ] Add intrusion detection (Fail2Ban)
- [ ] Create backup/restore procedures
- [ ] Implement CI/CD pipeline

## Project Files 📁
```
ServerSorcery101/
├── README.md (this file)
├── network-configs/
│   └── netplan-examples.yaml
└── scripts/
    └── security-hardening.sh
```

## References & Resources 📚

- [Ubuntu Server Documentation](https://ubuntu.com/server/docs)
- [VirtualBox Documentation](https://www.virtualbox.org/manual/)
- [UFW Essentials](https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands)
- [SSH Key Management](https://www.ssh.com/academy/ssh/keygen)

## Acknowledgments 🙏

This project was completed as part of learning DevOps fundamentals, with focus on practical, hands-on experience building production-grade infrastructure.

---

**Project Status:** Core infrastructure complete ✅  
**Next Milestone:** Server role configuration  
**Estimated Completion:** 