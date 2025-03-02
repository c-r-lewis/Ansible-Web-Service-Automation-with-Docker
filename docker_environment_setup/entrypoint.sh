#!/bin/sh

# Install OpenSSH server
apk add --no-cache openssh

# Install OpenSSH SFTP server
apk add --no-cache openssh-sftp-server

# Install python
apk add --no-cache python3

# Generate SSH host keys if they don't exist
ssh-keygen -A

# Start the SSH daemon
echo "Starting SSH daemon..."
/usr/sbin/sshd -D -e



