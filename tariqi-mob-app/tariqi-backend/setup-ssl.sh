#!/bin/bash

# Install certbot
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx

# Stop Nginx temporarily
sudo systemctl stop nginx

# Obtain SSL certificate
sudo certbot --nginx -d your-domain.com

# Test the renewal process
sudo certbot renew --dry-run

# Start Nginx
sudo systemctl start nginx

# Add renewal cron job
echo "0 0 * * * root certbot renew --quiet" | sudo tee -a /etc/crontab > /dev/null 