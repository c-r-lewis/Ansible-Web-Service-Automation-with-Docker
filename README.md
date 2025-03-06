
# Ansible automation to install Web Services 

This project demonstrates using **Ansible** to install and configure web services (such as **Nginx** and **PHP**) on a **Docker container** from a local host. The primary goal of this project is to automate the setup of a development environment using **Docker** and **Ansible**, making it easy to test Ansible playbooks without needing access to remote servers or multiple physical machines.

## Project Architecture

```plaintext
.
├── ansible
│   ├── inventory.ini          
│   └── setup_services.yml     
├── config
│   └── test_environment.conf  
├── docker_environment_setup
│   ├── docker-compose.yml     
│   ├── entrypoint.sh          
│   ├── sshd_config            
│   └── web
│       └── index.php          
├── README.md                  
└── web
    └── index.php              
```

## 1. **Configure Docker Environment**

The first step is configuring the Docker container to allow Ansible to communicate via SSH. This section covers setting up SSH and installing required services.

### **Generate SSH Key**

An SSH key pair must be generated to connect securely to the Docker container from the host machine. Run the following command to generate the key pair:

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

This command will generate a new SSH key pair (`id_rsa` and `id_rsa.pub`) in your default `.ssh` directory.

### **Copy SSH Key to `authorized_keys`**

To allow the Docker container to authenticate the host machine, copy the public SSH key to the container's `authorized_keys` file:

```bash
cat ~/.ssh/id_rsa.pub > authorized_keys
```

This will add the public key to the `authorized_keys` file, enabling passwordless authentication.

### **Set Correct Permissions for `authorized_keys`**

Ensure the `authorized_keys` file has the correct permissions to avoid authentication errors:

```bash
sudo chown root:root authorized_keys
sudo chmod 600 authorized_keys
```

This will ensure that the root user owns the file and that the file is only readable by the owner.

### **Configure SSH Daemon (`sshd_config`)**

The Docker container needs to be configured to allow SSH access. Here's the `sshd_config` file configuration that should be used inside the Docker container:

```plaintext
Port 22
PermitRootLogin yes
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile /root/.ssh/authorized_keys
Subsystem sftp /usr/lib/ssh/sftp-server
```

This configuration ensures:
- **Port 22**: SSH is accessible on port 22.
- **PermitRootLogin**: The root user can log in with public key authentication only (no password login).
- **PubkeyAuthentication**: Only public key authentication is allowed.


## 2. **Docker Compose Setup**

Next, set up the Docker environment using Docker Compose. The `docker-compose.yml` file defines the services required to run the container, such as the web server (Nginx) and SSH access.

### **docker-compose.yml**

The `docker-compose.yml` file defines a single service, `app`, a Docker container based on the `alpine:3.14` image.

```yaml
services:
  app:
    image: alpine:3.14
    container_name: test_environment
    ports:
      - "2222:22"  # Exposes SSH port
      - "8080:80"  # Exposes HTTP port for the web service
    entrypoint: /entrypoint.sh  # Runs the entrypoint script upon container startup
    volumes:
      - ./sshd_config:/etc/ssh/sshd_config
      - ./authorized_keys:/root/.ssh/authorized_keys
      - ./entrypoint.sh:/entrypoint.sh
```

**Explanation**:
- **`ports`**: The Docker container exposes SSH on port `2222` and HTTP (for the web service) on port `8080`.
- **`volumes`**: It mounts the SSH configuration, authorized keys, and entrypoint script into the container.

### **`entrypoint.sh` File**

The entrypoint script (`entrypoint.sh`) is executed when the container starts. It installs OpenSSH, Python (required by Ansible), and starts the SSH daemon:

```bash
#!/bin/sh

# Install OpenSSH server
apk add --no-cache openssh

# Install OpenSSH SFTP server
apk add --no-cache openssh-sftp-server

# Install Python (required for Ansible to function)
apk add --no-cache python3

# Generate SSH host keys if they don't exist
ssh-keygen -A

# Start the SSH daemon
echo "Starting SSH daemon..."
/usr/sbin/sshd -D -e
```

**Explanation**:
- **`apk add --no-cache`**: Installs packages without caching them, saving space in the container.
- **`ssh-keygen -A`**: Generates SSH host keys if they don't already exist, ensuring SSH functionality.

## 3. **Ansible Configuration**

Ansible requires a configuration file (inventory) and a playbook to interact with the Docker container and install the web services.

### **Inventory File (`inventory.ini`)**

The inventory file defines the connection details for Ansible to connect to the Docker container:

```ini
[docker]
test_environment ansible_host=127.0.0.1 ansible_port=2222 ansible_user=root
```

**Explanation**:
- **`ansible_host`**: Specifies the host (IP address or domain name) to connect to.
- **`ansible_port`**: Specifies the SSH port (2222).
- **`ansible_user`**: Specifies the user to log in as (root user).

### **Ansible Playbook (`setup_services.yml`)**

This playbook installs and configures web services (Nginx, PHP) on the Docker container.

```yaml
- name: Install and Configure Web Services
  hosts: docker
  become: yes  # Elevates to root privileges for installing services
  tasks:
    - name: Update apk cache
      apk:
        update_cache: yes

    - name: Install required packages
      apk:
        name:
          - nginx
          - php83
          - php83-fpm
          - php83-mysqli
          - php83-session
          - php83-json
          - openrc
        state: present

    - name: Enable OpenRC services
      command: openrc
      args:
        creates: /run/openrc/softlevel

    - name: Start OpenRC
      command: touch /run/openrc/softlevel

    - name: Add PHP-FPM83 to OpenRC
      command: rc-update add php-fpm83 default

    - name: Start PHP-FPM83
      command: rc-service php-fpm83 start

    - name: Copy nginx config file
      copy: 
        src: ../config/test_environment.conf
        dest: /etc/nginx/http.d/default.conf

    - name: Ensure Nginx is running
      command: rc-service nginx restart

    - name: Copy website files
      copy:
        src: ../web/index.php
        dest: /var/www/localhost/htdocs/index.php

  handlers:
    - name: Restart Nginx
      command: rc-service nginx restart

    - name: Restart PHP-FPM83
      command: rc-service php-fpm83 restart
```

**Explanation**:
- **`apk` module**: Used to install packages (e.g., `nginx`, `php83`, `openrc`).
- **`copy` module**: Copy configuration files and website files into the container.
- **`rc-service` and `rc-update` commands**: Used to manage services like Nginx and PHP-FPM.

## 4. **Testing and Adapting for Non-Virtual Clients**

### **Testing with Docker Containers**

In this project, I used **Docker containers** as a testing environment because it allows for easy testing of Ansible playbooks on a single machine (localhost) without needing multiple physical machines or remote servers. 

### **Adapting for Non-Virtual (Physical) Machines**

If you want to adapt the project to install services on an actual physical machine (non-virtual), you need to modify the **inventory file** and configure the **SSH access** to the non-virtual machine:

1. **Update Inventory File (`inventory.ini`)**:
   - Replace the Docker container's local IP (`127.0.0.1`) with the **IP address** of your physical machine.
   - For example, if your physical machine's IP is `192.168.1.100`, update the file like this:

   ```ini
   [physical_machines]
   test_environment ansible_host=192.168.1.100 ansible_user=root
   ```

The tag [docker] corresponds to the group name. In Ansible, the group name is used to categorize and organize hosts in your inventory file. It allows you to target a specific set of hosts (or containers, VMs, physical machines, etc.) when running a playbook. You can define multiple groups in your inventory file, each containing one or more hosts. I've updated the group name to [physical_machines] for clarity in this example. If you change the group name, you'll also need to update the hosts in the playbook to the updated group name.

2. **Ensure SSH Access**:
   - Ensure SSH is enabled on the physical machine.
   - Copy the SSH public key from your host machine to the physical machine's `authorized_keys` file, as described earlier.

3. **Run the Playbook**:
   - You can now use the same Ansible playbook to install the services directly on the physical machine by running the playbook with the updated inventory.



## 5. **Potential Problems**

### **Issue: Remote Host Identification Changed**

If you encounter the error message `REMOTE HOST IDENTIFICATION HAS CHANGED` when trying to connect via SSH, you can fix it by removing the outdated key from your `known_hosts` file:

```bash
ssh-keygen -f '/home/depinfo/.ssh/known_hosts' -R '[127.0.0.1]:2222'
```

This will allow you to reconnect to the Docker container or physical machine without the authentication error.

