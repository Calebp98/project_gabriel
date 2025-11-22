#!/bin/bash
# Simple wrapper to run Python scripts with the virtual environment

# Activate virtual environment
source "$(dirname "$0")/venv/bin/activate"

# Run the test script
python3 test_swd.py "$@"
