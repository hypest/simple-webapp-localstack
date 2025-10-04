#!/bin/bash
set -e

# DEPRECATED: This script is no longer needed
# SSH keys are now managed entirely by Terraform and extracted dynamically
# by the ssh-into-instance.sh script. No filesystem keys are created.

echo "ℹ️  This script is deprecated."
echo "📋 SSH keys are now managed by Terraform:"
echo "   - Terraform generates and stores keys in state"
echo "   - ssh-into-instance.sh extracts keys dynamically"
echo "   - No filesystem key files are created"
echo ""
echo "🚀 To connect to instances, use: ./scripts/ssh-into-instance.sh"
echo ""
echo "✅ No action needed - SSH key management is fully automated"