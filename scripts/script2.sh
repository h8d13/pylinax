#!/bin/bash
echo "=== GPU Info ==="
lspci | grep -i "3D\|VGA"
