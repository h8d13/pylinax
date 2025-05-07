#!/bin/bash
echo "=== CPU Info ==="
lscpu | grep -E 'Model name|Socket|Thread|Core|CPU(s)'
