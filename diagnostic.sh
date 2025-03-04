#!/bin/bash

# diagnostics.sh - System Diagnostic Collection Script
# Run with sudo for full system information access
# Usage: ./diagnostics.sh [-o output_file]

# Colors for better readability
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default output is terminal
OUTPUT_FILE="/dev/stdout"
SAVE_TO_FILE=false

# Parse command-line options
while getopts "o:" opt; do
    case $opt in
        o)
            OUTPUT_FILE="$OPTARG"
            SAVE_TO_FILE=true
            ;;
        ?)
            echo "Usage: $0 [-o output_file]"
            echo "  -o: Save output to specified file (e.g., -o diag.txt)"
            exit 1
            ;;
    esac
done

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}===== $1 =====${NC}"
    echo "----------------------------------------"
}

# All output piped to tee once at the end
{
    echo "System Diagnostic Report"
    echo "Generated: $(date)"
    echo "----------------------------------------"
    # Storage 
    print_section "Storage Utilization"
    df -h | awk 'NR==1 || $5+0 >= 90 || $6 ~ /^\/mnt\/[c-e]/ {print}'  # Show header, >90% usage, or Windows mounts
    echo -e "\nBlock Devices:"
    lsblk -o NAME,SIZE,RO,TYPE,MOUNTPOINTS -e 7  # Exclude loop devices

    # RAM Usage
    print_section "RAM Usage"
    free -h | grep -E 'Mem:|Swap:'

    # Running Services/Applications
    print_section "Running Services"
    echo "Key Services Status:"
    for svc in sshd cron; do systemctl is-active $svc &>/dev/null && echo "  $svc: Running" || echo "  $svc: Stopped"; done
    echo -e "\nTop Memory Consumers:"
    ps aux --sort=-%mem | head -n 4 | awk '{print "  " $11 " (" $6/1024 "MB)"}'
    
    # CPU Information
    print_section "CPU Usage"
    top -bn1 | head -n 7  # Top summary only
    echo -e "\nTop Processes:"
    top -bn1 | head -n 10 | tail -n 3  # Top 3 processes
    echo -e "\nCPU Info:"
    lscpu | grep -E "Architecture|Model name|CPU\(s\):|Thread\(s\)|Core\(s\)" | sed 's/^[[:space:]]*//'

    # Hardware Health
    print_section "Hardware Health"
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        echo "CPU Temp:"; echo "  $(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))°C"
    fi
    echo -e "\nDisk Health:"; smartctl -H /dev/sda | grep "result" || echo "  SMART not available"
    
    # OS Information
    print_section "Operating System Details"
    echo "OS Release:"; cat /etc/os-release | grep -E "PRETTY_NAME|VERSION=" | sed 's/^[[:space:]]*//'
    echo -e "\nKernel:"; uname -r
    echo -e "\nUptime:"; uptime -p

    # Network Information
    print_section "Network Status"
    echo "Default Gateway Ping:"; ping -c 4 8.8.8.8 | tail -n 2
    echo -e "\nDNS Resolution:"; nslookup google.com | grep -E "Name:|Address:"
    echo -e "\nInterface Traffic:"; ip -s link show | grep -E "RX:|TX:" | awk '{print "  " $0}'

    # Security Status
    print_section "Security Status"
    echo "Firewall:"; ufw status | grep -q "active" && echo "  Active" || echo "  Inactive"
    echo -e "\nFailed Logins (Last 10):"; journalctl -u sshd | grep "Failed password" | tail -n 10 | sed 's/^[[:space:]]*/  /'
    echo -e "\nOpen Ports:"; ss -tuln | awk 'NR>1 {print "  " $5}' | sort -u

    # General System Information
    print_section "General System Information"
    echo "Hostname: $(hostname)"
    echo "CPU Model:"; cat /proc/cpuinfo | grep "model name" | head -n 1 | cut -d':' -f2 | sed 's/^[[:space:]]*//'
    echo "Processes Running:"; ps aux | wc -l
    echo -e "\nNetwork IPs:"
    ip addr show | grep inet | awk '{print $2}' | sed 's/^[[:space:]]*//'

    # System Logs
    print_section "System Logs (Warnings and Errors)"
    echo "Last 20 Critical Logs:"
    journalctl -p 3 -xb | grep -Ei "error|failed|critical" | tail -n 20  # Filter and limit to 20
    echo -e "\nFailed Services:"
    systemctl --failed | grep -E "loaded|SUB" | sed 's/^[[:space:]]*//'
} | tee "$OUTPUT_FILE"  # Changed from -a to avoid appending issues

# Set file permissions and provide feedback
if [ "$SAVE_TO_FILE" = true ]; then
    chmod 600 "$OUTPUT_FILE"
    echo -e "\n${BLUE}Diagnostic collection complete. Output saved to: $OUTPUT_FILE${NC}"
else
    echo -e "\n${BLUE}Diagnostic collection complete. Output displayed above.${NC}"
fi

echo "Please review the output and share with your helpdesk team as needed."
