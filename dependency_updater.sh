#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to display usage
usage() {
    cat << EOF
Usage: $0 -a <artifactId> -v <new-version> -b <branches> [-d <base-directory>]

Options:
    -a    Artifact ID to update (e.g., common-lib)
    -v    New version (e.g., 1.2.3)
    -b    Target branches: develop, release, or both
    -d    Base directory containing services (default: current directory)
    -h    Display this help message

Examples:
    $0 -a common-lib -v 1.2.3 -b both
    $0 -a common-lib -v 1.2.3 -b develop -d /path/to/services
EOF
    exit 1
}

# Parse command line arguments
while getopts "a:v:b:d:h" opt; do
    case $opt in
        a) ARTIFACT_ID="$OPTARG" ;;
        v) NEW_VERSION="$OPTARG" ;;
        b) BRANCHES="$OPTARG" ;;
        d) BASE_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required parameters
if [[ -z "$ARTIFACT_ID" || -z "$NEW_VERSION" || -z "$BRANCHES" ]]; then
    log_error "Missing required parameters"
    usage
fi

# Validate branches parameter
if [[ "$BRANCHES" != "develop" && "$BRANCHES" != "release" && "$BRANCHES" != "both" ]]; then
    log_error "Invalid branches parameter. Must be: develop, release, or both"
    exit 1
fi

# Set base directory
BASE_DIR="${BASE_DIR:-.}"
cd "$BASE_DIR" || exit 1

log_info "Starting update process..."
log_info "Artifact ID: $ARTIFACT_ID"
log_info "New Version: $NEW_VERSION"
log_info "Target Branches: $BRANCHES"
log_info "Base Directory: $(pwd)"
echo ""

# Function to check if directory is a git repository
is_git_repo() {
    local dir="$1"
    [[ -d "$dir/.git" ]]
}

# Function to increment service version
increment_version() {
    local version="$1"
    local branch_type="$2"
    
    # Extract base version (X.Y.Z) and subversion
    if [[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(SNAPSHOT|RC)-([0-9]+)$ ]]; then
        local base="${BASH_REMATCH[1]}"
        local type="${BASH_REMATCH[2]}"
        local sub="${BASH_REMATCH[3]}"
        
        # Increment subversion
        sub=$((sub + 1))
        
        # Return with correct type based on branch
        if [[ "$branch_type" == "release" ]]; then
            echo "${base}-RC-${sub}"
        else
            echo "${base}-SNAPSHOT-${sub}"
        fi
    else
        log_warning "Unable to parse version: $version"
        echo "$version"
    fi
}

# Function to get current version from pom.xml
get_current_version() {
    local pom_file="$1"
    grep -m1 "<version>" "$pom_file" | sed -E 's/.*<version>(.*)<\/version>.*/\1/' | xargs
}

# Function to update pom.xml
update_pom() {
    local pom_file="$1"
    local artifact_id="$2"
    local new_version="$3"
    local service_version="$4"
    
    # Update dependency version
    sed -i.bak "/<artifactId>${artifact_id}<\/artifactId>/,/<\/version>/ s|<version>[^<]*</version>|<version>${new_version}</version>|" "$pom_file"
    
    # Update project version (first occurrence only)
    sed -i.bak "0,/<version>/s|<version>[^<]*</version>|<version>${service_version}</version>|" "$pom_file"
    
    rm -f "${pom_file}.bak"
}

# Function to update release.txt
update_release_txt() {
    local file="$1"
    local new_version="$2"
    
    if [[ -f "$file" ]]; then
        echo "$new_version" > "$file"
    fi
}

# Function to update release_notes.txt
update_release_notes() {
    local file="$1"
    local artifact_id="$2"
    local new_version="$3"
    
    local note="Update ${artifact_id} version to ${new_version}"
    
    if [[ -f "$file" ]]; then
        # Prepend to existing file
        echo -e "${note}\n$(cat $file)" > "$file"
    else
        # Create new file
        echo "$note" > "$file"
    fi
}

# Function to stash uncommitted changes
stash_changes() {
    local service_dir="$1"
    local branch_name="$2"
    
    cd "$service_dir" || return 1
    
    if ! git diff-index --quiet HEAD --; then
        log_warning "Uncommitted changes detected. Creating stash branch..."
        
        # Create and switch to new branch
        git checkout -b "$branch_name"
        git add .
        git commit -m "Stash: Uncommitted changes before ${ARTIFACT_ID} update"
        
        log_success "Changes saved to branch: $branch_name"
        return 0
    fi
    
    return 1
}

# Function to create PR (GitHub CLI)
create_github_pr() {
    local branch_name="$1"
    local base_branch="$2"
    local title="$3"
    local body="$4"
    
    if command -v gh &> /dev/null; then
        gh pr create --base "$base_branch" --head "$branch_name" --title "$title" --body "$body"
        return $?
    else
        log_warning "GitHub CLI not found. Please create PR manually for branch: $branch_name"
        return 1
    fi
}

# Function to process a single service
process_service() {
    local service_dir="$1"
    local branch_name="$2"
    local version_suffix="$3"
    
    log_info "Processing service: $(basename "$service_dir") on branch: $branch_name"
    
    cd "$service_dir" || return 1
    
    # Fetch latest changes
    git fetch origin
    
    # Check if branch exists remotely
    if ! git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
        log_error "Branch $branch_name does not exist in remote"
        return 1
    fi
    
    # Checkout target branch
    git checkout "$branch_name"
    git pull origin "$branch_name"
    
    # Check for uncommitted changes and stash if needed
    local stash_branch_name="${ARTIFACT_ID}-${NEW_VERSION}-${version_suffix}-unneeded-changes"
    local had_stashed_changes=false
    
    if stash_changes "$service_dir" "$stash_branch_name"; then
        had_stashed_changes=true
        # Go back to target branch
        git checkout "$branch_name"
    fi
    
    # Check if pom.xml exists
    if [[ ! -f "pom.xml" ]]; then
        log_warning "No pom.xml found, skipping..."
        return 0
    fi
    
    # Get current service version
    local current_service_version=$(get_current_version "pom.xml")
    log_info "Current service version: $current_service_version"
    
    # Increment service version
    local branch_type="develop"
    [[ "$branch_name" == "release" ]] && branch_type="release"
    
    local new_service_version=$(increment_version "$current_service_version" "$branch_type")
    log_info "New service version: $new_service_version"
    
    # Determine new dependency version with correct suffix
    local dependency_version="${NEW_VERSION}-${version_suffix}"
    
    # Create update branch
    local update_branch_name="${ARTIFACT_ID}-${NEW_VERSION}-updates"
    git checkout -b "$update_branch_name"
    
    # Update files
    update_pom "pom.xml" "$ARTIFACT_ID" "$dependency_version" "$new_service_version"
    update_release_txt "release.txt" "$new_service_version"
    update_release_notes "release_notes.txt" "$ARTIFACT_ID" "$dependency_version"
    
    # Commit changes
    git add pom.xml release.txt release_notes.txt 2>/dev/null
    git commit -m "Update ${ARTIFACT_ID} to version ${dependency_version}

- Updated ${ARTIFACT_ID} dependency version
- Incremented service version to ${new_service_version}
- Updated release notes"
    
    # Push update branch
    git push origin "$update_branch_name"
    
    # Create PR
    local pr_title="Update ${ARTIFACT_ID} to ${dependency_version}"
    local pr_body="This PR updates the ${ARTIFACT_ID} dependency to version ${dependency_version}.

Changes:
- Updated ${ARTIFACT_ID} version in pom.xml
- Incremented service version to ${new_service_version}
- Updated release.txt and release_notes.txt

$( [[ "$had_stashed_changes" == true ]] && echo "⚠️ Note: Uncommitted changes were saved to branch: ${stash_branch_name}" )"
    
    create_github_pr "$update_branch_name" "$branch_name" "$pr_title" "$pr_body"
    
    # Return to base branch
    git checkout "$branch_name"
    
    log_success "Service $(basename "$service_dir") processed successfully"
    echo ""
}

# Main processing loop
total_services=0
processed_services=0
failed_services=0

for service_dir in */; do
    # Remove trailing slash
    service_dir="${service_dir%/}"
    
    # Check if it's a git repository
    if ! is_git_repo "$service_dir"; then
        log_warning "Skipping $service_dir (not a git repository)"
        continue
    fi
    
    total_services=$((total_services + 1))
    
    # Process based on selected branches
    case "$BRANCHES" in
        develop)
            if process_service "$service_dir" "develop" "SNAPSHOT"; then
                processed_services=$((processed_services + 1))
            else
                failed_services=$((failed_services + 1))
            fi
            ;;
        release)
            if process_service "$service_dir" "release" "RC"; then
                processed_services=$((processed_services + 1))
            else
                failed_services=$((failed_services + 1))
            fi
            ;;
        both)
            local success=true
            if ! process_service "$service_dir" "develop" "SNAPSHOT"; then
                success=false
            fi
            if ! process_service "$service_dir" "release" "RC"; then
                success=false
            fi
            
            if $success; then
                processed_services=$((processed_services + 1))
            else
                failed_services=$((failed_services + 1))
            fi
            ;;
    esac
done

# Summary
echo ""
log_info "========================================="
log_info "Update Summary"
log_info "========================================="
log_info "Total services found: $total_services"
log_success "Successfully processed: $processed_services"
[[ $failed_services -gt 0 ]] && log_error "Failed: $failed_services" || log_info "Failed: 0"
log_info "========================================="

exit 0