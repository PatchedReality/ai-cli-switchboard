#!/bin/bash
# Universal Stop Script for All Model Types

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-utils.sh"

# Use the shared stop function
stop_all_services