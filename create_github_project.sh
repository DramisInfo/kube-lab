#!/bin/bash

# Script to create GitHub Issues from README tasks using GitHub CLI
# Usage: ./create_github_project.sh <repo>

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Missing repository name${NC}"
    echo "Usage: $0 <repo>"
    echo "Example: $0 kube-lab"
    exit 1
fi

REPO=$1
# Set the organization name
OWNER="dramisinfo"

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed. Please install it first:${NC}"
    echo "https://cli.github.com/manual/installation"
    exit 1
fi

# Check if the user is authenticated with GitHub CLI
gh auth status &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: You are not logged in to GitHub CLI. Please run 'gh auth login' first.${NC}"
    exit 1
fi

# Check if you have access to the organization
echo -e "${BLUE}Checking if you have access to organization $OWNER...${NC}"
gh api orgs/$OWNER &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: You don't have access to the organization $OWNER or it doesn't exist.${NC}"
    echo -e "${YELLOW}Please make sure:${NC}"
    echo -e "1. The organization exists"
    echo -e "2. You are a member of the organization"
    echo -e "3. You have given GitHub CLI access to the organization during authentication"
    exit 1
fi

# Check if the repository exists on GitHub
echo -e "${BLUE}Checking if repository $OWNER/$REPO exists on GitHub...${NC}"
gh repo view "$OWNER/$REPO" &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}Repository $OWNER/$REPO does not exist on GitHub.${NC}"
    echo -e "${YELLOW}Would you like to create it now? (y/n)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Creating repository $OWNER/$REPO on GitHub...${NC}"
        gh repo create "$OWNER/$REPO" --source=. --push --public
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create repository in the organization. Please create it manually:${NC}"
            echo -e "1. Go to ${BLUE}https://github.com/organizations/$OWNER/repositories/new${NC}"
            echo -e "2. Create a new repository named '${BLUE}$REPO${NC}'"
            echo -e "3. Run: ${YELLOW}git remote add origin git@github.com:$OWNER/$REPO.git${NC}"
            echo -e "4. Run: ${YELLOW}git push -u origin main${NC}"
            echo -e "5. Then run this script again"
            exit 1
        fi
    else
        echo -e "${YELLOW}Please create the repository first:${NC}"
        echo -e "1. Go to ${BLUE}https://github.com/organizations/$OWNER/repositories/new${NC}"
        echo -e "2. Create a new repository named '${BLUE}$REPO${NC}'"
        echo -e "3. Run: ${YELLOW}git remote add origin git@github.com:$OWNER/$REPO.git${NC}"
        echo -e "4. Run: ${YELLOW}git push -u origin main${NC}"
        echo -e "5. Then run this script again"
        exit 1
    fi
fi

echo -e "${GREEN}Repository $OWNER/$REPO exists on GitHub.${NC}"
echo -e "${YELLOW}Creating GitHub Issues for $OWNER/$REPO${NC}"

# Define the tasks from the README "Plan of Tasks" section
declare -a PLAN_TASKS=(
    "Container Infrastructure Setup: Define Docker container configuration, create Dockerfile and docker-compose.yml files, configure networking"
    "PXE Boot Services Configuration: Set up DHCP server, configure TFTP server, prepare network boot environment"
    "Ubuntu Installation Media Preparation: Download Ubuntu installation media, extract and configure netboot images, create preseed configuration"
    "Boot Menu Configuration: Set up PXELinux or GRUB boot menu, configure boot options, add advanced options"
    "Post-Installation Configuration: Create scripts for post-installation setup, configure user accounts and system settings"
    "Testing and Validation: Test PXE boot process, validate installation process, verify post-installation configuration"
    "Documentation: Document setup and usage instructions, create troubleshooting guide, provide examples for customization"
)

# Create a label for the "Plan of Tasks" section
echo -e "${YELLOW}Creating 'Plan Task' label...${NC}"
gh label create "Plan Task" --description "Task from the Plan of Tasks section" --color 0E8A16 --repo "$OWNER/$REPO" || true

# Add each task as an issue
for task in "${PLAN_TASKS[@]}"; do
    TITLE=$(echo "$task" | cut -d':' -f1)
    BODY=$(echo "$task" | cut -d':' -f2- | sed 's/^ //')
    
    echo -e "${YELLOW}Creating issue: $TITLE${NC}"
    
    ISSUE_URL=$(gh issue create --title "$TITLE" --body "$BODY" --label "Plan Task" --repo "$OWNER/$REPO")
    
    if [ -n "$ISSUE_URL" ]; then
        echo -e "${GREEN}Created issue: $ISSUE_URL${NC}"
    else
        echo -e "${RED}Failed to create issue: $TITLE${NC}"
    fi
done

# Define the remaining tasks (to be added as issues)
declare -a REMAINING_TASKS=(
    "Complete PXE Boot Configuration: Test the complete PXE boot process with a client machine"
    "Complete User Documentation: Create comprehensive documentation for system operation"
    "Add Troubleshooting Section: Document common issues and their solutions"
    "Document Architecture: Provide detailed information about system architecture and configuration"
)

# Create a label for the "Remaining Tasks" section
echo -e "${YELLOW}Creating 'Remaining Task' label...${NC}"
gh label create "Remaining Task" --description "Task from the Remaining Tasks section" --color D93F0B --repo "$OWNER/$REPO" || true

# Add each remaining task as an issue
for task in "${REMAINING_TASKS[@]}"; do
    TITLE=$(echo "$task" | cut -d':' -f1)
    BODY=$(echo "$task" | cut -d':' -f2- | sed 's/^ //')
    
    echo -e "${YELLOW}Creating issue: $TITLE${NC}"
    
    ISSUE_URL=$(gh issue create --title "$TITLE" --body "$BODY" --label "Remaining Task" --repo "$OWNER/$REPO")
    
    if [ -n "$ISSUE_URL" ]; then
        echo -e "${GREEN}Created issue: $ISSUE_URL${NC}"
    else
        echo -e "${RED}Failed to create issue: $TITLE${NC}"
    fi
done

# Define the completed tasks (to be added as closed issues)
declare -a COMPLETED_TASKS=(
    "Fix Web UI: Web UI is accessible via HTTP, added symbolic links, verified Nginx configuration, fixed permissions, updated detection"
    "Set Up Node.js API Server: Server properly starting, service shows as RUNNING, API correctly configured, fixed status detection"
    "Set Up PXE Boot Configuration: Created placeholder files, set up TFTP boot environment, configured preseed files, created test script"
    "Fine-tune Network Configuration: DHCP server running, TFTP via dnsmasq working, fixed service conflicts, configured DHCP options"
    "Implement Logging and Monitoring: Added log viewing, system monitoring, connection monitoring, and auto-refresh functionality"
)

# Create a label for the "Completed Tasks" section
echo -e "${YELLOW}Creating 'Completed' label...${NC}"
gh label create "Completed" --description "Completed task" --color 0E8A16 --repo "$OWNER/$REPO" || true

# Add each completed task as a closed issue
for task in "${COMPLETED_TASKS[@]}"; do
    TITLE=$(echo "$task" | cut -d':' -f1)
    BODY=$(echo "$task" | cut -d':' -f2- | sed 's/^ //')
    BODY="✅ COMPLETED: $BODY"
    
    echo -e "${YELLOW}Creating closed issue: $TITLE${NC}"
    
    ISSUE_URL=$(gh issue create --title "$TITLE" --body "$BODY" --label "Completed" --repo "$OWNER/$REPO")
    
    if [ -n "$ISSUE_URL" ]; then
        # Close the issue since it's already completed
        ISSUE_NUMBER=${ISSUE_URL##*/}
        gh issue close "$ISSUE_NUMBER" --repo "$OWNER/$REPO"
        echo -e "${GREEN}Created and closed issue: $ISSUE_URL${NC}"
    else
        echo -e "${RED}Failed to create issue: $TITLE${NC}"
    fi
done

echo -e "${GREEN}GitHub Issues creation complete!${NC}"
echo -e "View all issues at: ${BLUE}https://github.com/$OWNER/$REPO/issues${NC}"