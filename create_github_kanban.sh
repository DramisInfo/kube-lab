#!/bin/bash

# Script to create a GitHub Project in Kanban mode and add existing issues to it
# Usage: ./create_github_kanban.sh <repo>

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
OWNER="DramisInfo"  # Note: Using proper case as shown in API response

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed. Please install it first:${NC}"
    echo "https://cli.github.com/manual/installation"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Please install it first:${NC}"
    echo "sudo apt install jq"
    exit 1
fi

# Check if the user is authenticated with GitHub CLI
echo -e "${BLUE}Checking GitHub authentication...${NC}"
AUTH_STATUS=$(gh auth status 2>&1)
if echo "$AUTH_STATUS" | grep -q "not logged in"; then
    echo -e "${RED}Error: You are not logged in to GitHub CLI. Please run 'gh auth login' first.${NC}"
    exit 1
else
    echo -e "${GREEN}Authenticated with GitHub.${NC}"
    echo "$AUTH_STATUS"
fi

# Check if you have access to the organization
echo -e "${BLUE}Checking if you have access to organization $OWNER...${NC}"
ORG_RESPONSE=$(gh api orgs/$OWNER 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: You don't have access to the organization $OWNER or it doesn't exist.${NC}"
    echo "Response: $ORG_RESPONSE"
    exit 1
else
    echo -e "${GREEN}Access to organization confirmed.${NC}"
fi

# Check if the repository exists on GitHub
echo -e "${BLUE}Checking if repository $OWNER/$REPO exists on GitHub...${NC}"
REPO_RESPONSE=$(gh repo view "$OWNER/$REPO" 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Repository $OWNER/$REPO does not exist on GitHub.${NC}"
    echo "Response: $REPO_RESPONSE"
    exit 1
else
    echo -e "${GREEN}Repository $OWNER/$REPO exists.${NC}"
fi

echo -e "${GREEN}Repository checks passed. Creating a new project...${NC}"

# Get the organization's node ID (needed for GraphQL)
echo -e "${BLUE}Getting organization node ID...${NC}"
ORG_NODE_ID=$(gh api graphql -f query='
query {
  organization(login: "'"$OWNER"'") {
    id
  }
}
' --jq '.data.organization.id' 2>&1)

if [ $? -ne 0 ] || [ -z "$ORG_NODE_ID" ]; then
    echo -e "${RED}Error: Could not get organization node ID.${NC}"
    echo "Response: $ORG_NODE_ID"
    exit 1
else
    echo -e "${GREEN}Organization node ID: $ORG_NODE_ID${NC}"
fi

# Step 1: Create a new project
echo -e "${YELLOW}Creating a new GitHub Project...${NC}"

# Create the project with title "PXE Boot Server"
PROJECT_TITLE="PXE Boot Server"
echo -e "${BLUE}Sending GraphQL mutation to create project...${NC}"

PROJECT_CREATE_RESPONSE=$(gh api graphql --raw-field query='
mutation {
  createProjectV2(input: {ownerId: "'"$ORG_NODE_ID"'", title: "'"$PROJECT_TITLE"'"}) {
    projectV2 {
      id
      number
      url
    }
  }
}
' 2>&1)

echo -e "${YELLOW}Project creation response:${NC}"
echo "$PROJECT_CREATE_RESPONSE"

# Parse the response to get project details
if echo "$PROJECT_CREATE_RESPONSE" | grep -q "\"data\""; then
    PROJECT_JSON=$(echo "$PROJECT_CREATE_RESPONSE" | jq -r '.data.createProjectV2.projectV2 // empty')
    if [ -z "$PROJECT_JSON" ]; then
        echo -e "${RED}Failed to parse project creation response.${NC}"
        exit 1
    fi
    
    PROJECT_ID=$(echo "$PROJECT_JSON" | jq -r '.id // empty')
    PROJECT_NUMBER=$(echo "$PROJECT_JSON" | jq -r '.number // empty')
    PROJECT_URL=$(echo "$PROJECT_JSON" | jq -r '.url // empty')
    
    if [ -z "$PROJECT_ID" ] || [ -z "$PROJECT_URL" ]; then
        echo -e "${RED}Failed to extract project details.${NC}"
        exit 1
    fi
else
    echo -e "${RED}Failed to create GitHub Project.${NC}"
    echo "Error response: $PROJECT_CREATE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}Created GitHub Project: $PROJECT_TITLE${NC}"
echo -e "${GREEN}Project ID: $PROJECT_ID${NC}"
echo -e "${GREEN}Project URL: $PROJECT_URL${NC}"

# Step 2: Add fields to the project (Status field is created by default)
echo -e "${YELLOW}Configuring project with Kanban fields...${NC}"

# Get the project fields to find the status field ID
echo -e "${BLUE}Getting project fields...${NC}"
PROJECT_FIELDS_RESPONSE=$(gh api graphql --raw-field query='
query {
  node(id: "'"$PROJECT_ID"'") {
    ... on ProjectV2 {
      fields(first: 20) {
        nodes {
          ... on ProjectV2Field {
            id
            name
          }
          ... on ProjectV2IterationField {
            id
            name
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}
' 2>&1)

echo -e "${YELLOW}Project fields response:${NC}"
echo "$PROJECT_FIELDS_RESPONSE"

if echo "$PROJECT_FIELDS_RESPONSE" | grep -q "\"data\""; then
    PROJECT_FIELDS=$(echo "$PROJECT_FIELDS_RESPONSE" | jq -r '.data.node.fields.nodes // empty')
    if [ -z "$PROJECT_FIELDS" ]; then
        echo -e "${RED}Failed to parse project fields response.${NC}"
        exit 1
    fi
    
    STATUS_FIELD_ID=$(echo "$PROJECT_FIELDS" | jq -r '.[] | select(.name=="Status") | .id // empty')
    
    if [ -z "$STATUS_FIELD_ID" ]; then
        echo -e "${RED}Could not find Status field in project.${NC}"
        
        # Try to create a Status field if it doesn't exist
        echo -e "${YELLOW}Attempting to create a Status field...${NC}"
        STATUS_FIELD_RESPONSE=$(gh api graphql --raw-field query='
        mutation {
          createProjectV2Field(input: {
            projectId: "'"$PROJECT_ID"'",
            dataType: SINGLE_SELECT,
            name: "Status"
          }) {
            projectV2Field {
              id
            }
          }
        }
        ' 2>&1)
        
        echo -e "${YELLOW}Status field creation response:${NC}"
        echo "$STATUS_FIELD_RESPONSE"
        
        if echo "$STATUS_FIELD_RESPONSE" | grep -q "\"data\""; then
            STATUS_FIELD_ID=$(echo "$STATUS_FIELD_RESPONSE" | jq -r '.data.createProjectV2Field.projectV2Field.id // empty')
            if [ -z "$STATUS_FIELD_ID" ]; then
                echo -e "${RED}Failed to create Status field.${NC}"
                exit 1
            else
                echo -e "${GREEN}Created Status field with ID: $STATUS_FIELD_ID${NC}"
            fi
        else
            echo -e "${RED}Failed to create Status field.${NC}"
            echo "Response: $STATUS_FIELD_RESPONSE"
            exit 1
        fi
    else
        echo -e "${GREEN}Found Status field with ID: $STATUS_FIELD_ID${NC}"
    fi
else
    echo -e "${RED}Failed to get project fields.${NC}"
    echo "Response: $PROJECT_FIELDS_RESPONSE"
    exit 1
fi

echo -e "${GREEN}GitHub Project setup complete!${NC}"
echo -e "Project URL: ${BLUE}$PROJECT_URL${NC}"
echo -e "${YELLOW}Note: You can now manually add your issues to this project through the GitHub web interface.${NC}"
echo -e "${YELLOW}Visit the project URL above, click on + Add item, and select issues to add.${NC}"