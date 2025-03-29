#!/bin/bash

# Script to add all existing issues from a repo to a GitHub Project
# Usage: ./add_issues_to_project.sh <repo> <project_number>

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Missing parameters${NC}"
    echo "Usage: $0 <repo> <project_number>"
    echo "Example: $0 kube-lab 5"
    exit 1
fi

REPO=$1
PROJECT_NUMBER=$2
OWNER="DramisInfo"

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

# Check GitHub authentication with project scope
echo -e "${BLUE}Checking GitHub authentication...${NC}"
AUTH_STATUS=$(gh auth status 2>&1)
if ! echo "$AUTH_STATUS" | grep -q "project"; then
    echo -e "${RED}Error: Your GitHub token does not have the 'project' scope.${NC}"
    echo -e "${YELLOW}Please refresh your token with:${NC}"
    echo "gh auth refresh -h github.com -s project"
    exit 1
fi
echo -e "${GREEN}GitHub authentication OK with project scope.${NC}"

# Get the project node ID
echo -e "${BLUE}Getting project ID for project number $PROJECT_NUMBER...${NC}"
PROJECT_INFO=$(gh api graphql --raw-field query='
query {
  organization(login: "'"$OWNER"'") {
    projectV2(number: '"$PROJECT_NUMBER"') {
      id
      title
    }
  }
}
' 2>&1)

if ! echo "$PROJECT_INFO" | grep -q "\"data\""; then
    echo -e "${RED}Error: Could not get project information. Response:${NC}"
    echo "$PROJECT_INFO"
    exit 1
fi

PROJECT_ID=$(echo "$PROJECT_INFO" | jq -r '.data.organization.projectV2.id')
PROJECT_TITLE=$(echo "$PROJECT_INFO" | jq -r '.data.organization.projectV2.title')

if [ -z "$PROJECT_ID" ] || [ -z "$PROJECT_TITLE" ]; then
    echo -e "${RED}Error: Could not extract project ID or title.${NC}"
    exit 1
fi

echo -e "${GREEN}Found project: $PROJECT_TITLE (ID: $PROJECT_ID)${NC}"

# Get the Status field ID
echo -e "${BLUE}Getting Status field ID...${NC}"
PROJECT_FIELDS=$(gh api graphql --raw-field query='
query {
  node(id: "'"$PROJECT_ID"'") {
    ... on ProjectV2 {
      fields(first: 20) {
        nodes {
          ... on ProjectV2Field {
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

if ! echo "$PROJECT_FIELDS" | grep -q "\"data\""; then
    echo -e "${RED}Error: Could not get project fields. Response:${NC}"
    echo "$PROJECT_FIELDS"
    exit 1
fi

STATUS_FIELD_JSON=$(echo "$PROJECT_FIELDS" | jq -r '.data.node.fields.nodes[] | select(.name=="Status")')
STATUS_FIELD_ID=$(echo "$STATUS_FIELD_JSON" | jq -r '.id')

if [ -z "$STATUS_FIELD_ID" ]; then
    echo -e "${RED}Error: Could not find Status field in project.${NC}"
    exit 1
fi

echo -e "${GREEN}Found Status field with ID: $STATUS_FIELD_ID${NC}"

# Get status option IDs for Todo, In Progress, Done
TODO_OPTION=$(echo "$STATUS_FIELD_JSON" | jq -r '.options[] | select(.name=="Todo" or .name=="To do")')
TODO_OPTION_ID=$(echo "$TODO_OPTION" | jq -r '.id')

DONE_OPTION=$(echo "$STATUS_FIELD_JSON" | jq -r '.options[] | select(.name=="Done")')
DONE_OPTION_ID=$(echo "$DONE_OPTION" | jq -r '.id')

if [ -z "$TODO_OPTION_ID" ] || [ -z "$DONE_OPTION_ID" ]; then
    echo -e "${RED}Error: Could not find required status options.${NC}"
    echo "Status field options:"
    echo "$STATUS_FIELD_JSON" | jq -r '.options'
    exit 1
fi

echo -e "${GREEN}Found status options: Todo: $TODO_OPTION_ID, Done: $DONE_OPTION_ID${NC}"

# Get all issues from the repository
echo -e "${BLUE}Getting all issues from $OWNER/$REPO...${NC}"
ISSUES=$(gh issue list --repo "$OWNER/$REPO" --json number,title,state --limit 100)
ISSUE_COUNT=$(echo "$ISSUES" | jq '. | length')

if [ "$ISSUE_COUNT" -eq 0 ]; then
    echo -e "${RED}No issues found in repository $OWNER/$REPO.${NC}"
    exit 1
fi

echo -e "${GREEN}Found $ISSUE_COUNT issues.${NC}"

# Loop through each issue and add it to the project
for (( i=0; i<$ISSUE_COUNT; i++ )); do
    ISSUE_NUMBER=$(echo "$ISSUES" | jq -r ".[$i].number")
    ISSUE_TITLE=$(echo "$ISSUES" | jq -r ".[$i].title")
    ISSUE_STATE=$(echo "$ISSUES" | jq -r ".[$i].state")
    
    echo -e "${YELLOW}Processing issue #$ISSUE_NUMBER: $ISSUE_TITLE (State: $ISSUE_STATE)${NC}"
    
    # Get the issue node ID
    ISSUE_INFO=$(gh api graphql --raw-field query='
    query {
      repository(owner: "'"$OWNER"'", name: "'"$REPO"'") {
        issue(number: '"$ISSUE_NUMBER"') {
          id
        }
      }
    }
    ' 2>&1)
    
    if ! echo "$ISSUE_INFO" | grep -q "\"data\""; then
        echo -e "${RED}Error getting issue node ID for #$ISSUE_NUMBER. Skipping.${NC}"
        continue
    fi
    
    ISSUE_NODE_ID=$(echo "$ISSUE_INFO" | jq -r '.data.repository.issue.id')
    
    if [ -z "$ISSUE_NODE_ID" ]; then
        echo -e "${RED}Could not extract issue node ID for #$ISSUE_NUMBER. Skipping.${NC}"
        continue
    fi
    
    # Add the issue to the project
    echo -e "${BLUE}Adding issue #$ISSUE_NUMBER to project...${NC}"
    ADD_RESPONSE=$(gh api graphql --raw-field query='
    mutation {
      addProjectV2ItemById(input: {
        projectId: "'"$PROJECT_ID"'",
        contentId: "'"$ISSUE_NODE_ID"'"
      }) {
        item {
          id
        }
      }
    }
    ' 2>&1)
    
    if ! echo "$ADD_RESPONSE" | grep -q "\"data\""; then
        if echo "$ADD_RESPONSE" | grep -q "already exists"; then
            echo -e "${YELLOW}Issue #$ISSUE_NUMBER is already in the project. Will update its status.${NC}"
            
            # Get the item ID for the issue that's already in the project
            ITEM_INFO=$(gh api graphql --raw-field query='
            query {
              organization(login: "'"$OWNER"'") {
                projectV2(number: '"$PROJECT_NUMBER"') {
                  items(first: 100) {
                    nodes {
                      id
                      content {
                        ... on Issue {
                          number
                          repository {
                            name
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            ' 2>&1)
            
            ITEM_ID=$(echo "$ITEM_INFO" | jq -r '.data.organization.projectV2.items.nodes[] | select(.content.number=='"$ISSUE_NUMBER"' and .content.repository.name=="'"$REPO"'") | .id')
            
            if [ -z "$ITEM_ID" ]; then
                echo -e "${RED}Could not find project item for issue #$ISSUE_NUMBER. Skipping status update.${NC}"
                continue
            fi
        else
            echo -e "${RED}Failed to add issue #$ISSUE_NUMBER to project. Skipping.${NC}"
            continue
        fi
    else
        ITEM_ID=$(echo "$ADD_RESPONSE" | jq -r '.data.addProjectV2ItemById.item.id')
        if [ -z "$ITEM_ID" ]; then
            echo -e "${RED}Could not extract item ID for issue #$ISSUE_NUMBER. Skipping status update.${NC}"
            continue
        fi
    fi
    
    # Set the status based on issue state
    STATUS_OPTION_ID="$TODO_OPTION_ID"
    if [ "$ISSUE_STATE" == "CLOSED" ]; then
        STATUS_OPTION_ID="$DONE_OPTION_ID"
    fi
    
    echo -e "${BLUE}Setting status for issue #$ISSUE_NUMBER...${NC}"
    STATUS_RESPONSE=$(gh api graphql --raw-field query='
    mutation {
      updateProjectV2ItemFieldValue(input: {
        projectId: "'"$PROJECT_ID"'",
        itemId: "'"$ITEM_ID"'",
        fieldId: "'"$STATUS_FIELD_ID"'",
        value: {
          singleSelectOptionId: "'"$STATUS_OPTION_ID"'"
        }
      }) {
        projectV2Item {
          id
        }
      }
    }
    ' 2>&1)
    
    if ! echo "$STATUS_RESPONSE" | grep -q "\"data\""; then
        echo -e "${RED}Failed to set status for issue #$ISSUE_NUMBER. Error:${NC}"
        echo "$STATUS_RESPONSE"
    else
        if [ "$ISSUE_STATE" == "CLOSED" ]; then
            echo -e "${GREEN}Issue #$ISSUE_NUMBER added to project and set to Done.${NC}"
        else
            echo -e "${GREEN}Issue #$ISSUE_NUMBER added to project and set to Todo.${NC}"
        fi
    fi
done

echo -e "${GREEN}All issues have been processed.${NC}"
echo -e "View your project board at: ${BLUE}https://github.com/orgs/$OWNER/projects/$PROJECT_NUMBER${NC}"