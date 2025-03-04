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

# Function to print section headers (no tee here to avoid duplication)
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# All output piped to tee once at the end
{
    echo "System Diagnostic Report - Generated on $(date)"
    echo "----------------------------------------"

    print_section "Storage Utilization"
    df -h
    echo ""
    lsblk

    print_section "RAM Usage"
    free -h

    print_section "CPU Usage"
    top -bn1 | head -n 10
    echo ""
    lscpu | grep -E "Architecture|Model name|CPU\(s\):|Thread\(s\)|Core\(s\)"

    print_section "Operating System Details"
    echo "OS Release:"
    cat /etc/os-release
    echo -e "\nKernel Version:"
    uname -r
    echo -e "\nUptime:"
    uptime

    print_section "General System Information"
    echo "Hostname: $(hostname)"
    echo "CPU Info:"
    cat /proc/cpuinfo | grep "model name" | head -n 1
    echo "Total Processes: $(ps aux | wc -l)"
    echo "Network Interfaces:"
    ip addr show | grep inet

    print_section "System Logs (Warnings and Errors)"
    echo "Last 50 System Log Errors/Warnings:"
    journalctl -p 3 -xb | tail -n 50
    echo -e "\nFailed Services:"
    systemctl --failed
} | tee -a "$OUTPUT_FILE"

# Set file permissions and provide feedback
if [ "$SAVE_TO_FILE" = true ]; then
    chmod 600 "$OUTPUT_FILE"
    echo -e "\n${BLUE}Diagnostic collection complete. Output saved to: $OUTPUT_FILE${NC}"
else
    echo -e "\n${BLUE}Diagnostic collection complete. Output displayed above.${NC}"
fi

echo "Please review the output and share with your helpdesk team as needed."
