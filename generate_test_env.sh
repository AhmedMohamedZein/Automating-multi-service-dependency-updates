#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
NUM_SERVICES=20
BASE_DIR="test-services"
COMMON_ARTIFACT_ID="common-lib"
COMMON_VERSION="1.0.0"
GIT_ORG="mycompany"
GIT_HOST="github.com"
CREATE_REMOTE_REPOS=false
REPO_VISIBILITY="public"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [-n <number>] [-d <directory>] [-c <common-artifact-id>] [-v <common-version>] [-o <git-org>] [-g <git-host>] [-r] [-p]

Options:
    -n    Number of services to generate (default: 20)
    -d    Base directory name (default: test-services)
    -c    Common library artifact ID (default: common-lib)
    -v    Common library version (default: 1.0.0)
    -o    Git organization/user name (default: mycompany)
    -g    Git host (default: github.com, only github.com supported for auto-creation)
    -r    Create remote repositories on GitHub (requires gh CLI)
    -p    Make repositories private (default: public)
    -h    Display this help message

Examples:
    # Generate with local repos only
    $0 -n 20 -o ZEIN-TEST

    # Generate and create remote repos on GitHub
    $0 -n 20 -o ZEIN-TEST -r

    # Generate private repos
    $0 -n 20 -o ZEIN-TEST -r -p
EOF
    exit 1
}

# Parse command line arguments
while getopts "n:d:c:v:o:g:rph" opt; do
    case $opt in
        n) NUM_SERVICES="$OPTARG" ;;
        d) BASE_DIR="$OPTARG" ;;
        c) COMMON_ARTIFACT_ID="$OPTARG" ;;
        v) COMMON_VERSION="$OPTARG" ;;
        o) GIT_ORG="$OPTARG" ;;
        g) GIT_HOST="$OPTARG" ;;
        r) CREATE_REMOTE_REPOS=true ;;
        p) REPO_VISIBILITY="private" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check if gh CLI is installed when remote creation is requested
if [[ "$CREATE_REMOTE_REPOS" == true ]]; then
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed!"
        log_info "Install it from: https://cli.github.com/"
        log_info "Or run without -r flag to skip remote repository creation"
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI!"
        log_info "Run: gh auth login"
        exit 1
    fi
    
    log_success "GitHub CLI detected and authenticated"
fi

log_info "Starting test environment generation..."
log_info "Number of services: $NUM_SERVICES"
log_info "Base directory: $BASE_DIR"
log_info "Common artifact ID: $COMMON_ARTIFACT_ID"
log_info "Common version: $COMMON_VERSION"
log_info "Git organization: $GIT_ORG"
log_info "Git host: $GIT_HOST"
log_info "Create remote repos: $CREATE_REMOTE_REPOS"
if [[ "$CREATE_REMOTE_REPOS" == true ]]; then
    log_info "Repository visibility: $REPO_VISIBILITY"
fi
echo ""

# Create base directory
if [[ -d "$BASE_DIR" ]]; then
    log_warning "Directory $BASE_DIR already exists. Do you want to remove it? (y/n)"
    read -r response
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        rm -rf "$BASE_DIR"
        log_info "Removed existing directory"
    else
        log_error "Aborting..."
        exit 1
    fi
fi

mkdir -p "$BASE_DIR"
cd "$BASE_DIR" || exit 1

# Function to generate pom.xml
generate_pom() {
    local service_name="$1"
    local service_version="$2"
    local common_version="$3"
    local group_id="com.company.services"
    
    cat > pom.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>${group_id}</groupId>
    <artifactId>${service_name}</artifactId>
    <version>${service_version}</version>
    <packaging>jar</packaging>

    <name>${service_name}</name>
    <description>Test service ${service_name}</description>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
        <relativePath/>
    </parent>

    <properties>
        <java.version>17</java.version>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
    </properties>

    <dependencies>
        <!-- Common Library -->
        <dependency>
            <groupId>${group_id}</groupId>
            <artifactId>${COMMON_ARTIFACT_ID}</artifactId>
            <version>${common_version}</version>
        </dependency>

        <!-- Spring Boot Starter Web -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- Spring Boot Starter Test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOF
}

# Function to generate release.txt
generate_release_txt() {
    local version="$1"
    echo "$version" > release.txt
}

# Function to generate release_notes.txt
generate_release_notes() {
    local service_name="$1"
    local version="$2"
    
    cat > release_notes.txt << EOF
Release Notes for ${service_name}
Version: ${version}

Initial release
- Service setup
- Basic configuration
- Dependencies configured
EOF
}

# Function to generate README.md
generate_readme() {
    local service_name="$1"
    
    cat > README.md << EOF
# ${service_name}

This is a test microservice generated for testing the dependency updater script.

## Build
\`\`\`bash
mvn clean install
\`\`\`

## Run
\`\`\`bash
mvn spring-boot:run
\`\`\`

## Branches
- \`develop\`: Development branch with SNAPSHOT versions
- \`release\`: Release branch with RC versions
EOF
}

# Function to generate .gitignore
generate_gitignore() {
    cat > .gitignore << 'EOF'
target/
!.mvn/wrapper/maven-wrapper.jar
!**/src/main/**/target/
!**/src/test/**/target/

### STS ###
.apt_generated
.classpath
.factorypath
.project
.settings
.springBeans
.sts4-cache

### IntelliJ IDEA ###
.idea
*.iws
*.iml
*.ipr

### NetBeans ###
/nbproject/private/
/nbbuild/
/dist/
/nbdist/
/.nb-gradle/
build/
!**/src/main/**/build/
!**/src/test/**/build/

### VS Code ###
.vscode/

### Maven ###
.mvn/
mvnw
mvnw.cmd
EOF
}

# Function to create remote repository on GitHub
create_github_repo() {
    local service_name="$1"
    local repo_full_name="${GIT_ORG}/${service_name}"
    
    log_info "Creating GitHub repository: $repo_full_name"
    
    # Check if repo already exists
    if gh repo view "$repo_full_name" &> /dev/null; then
        log_warning "Repository $repo_full_name already exists, skipping creation"
        return 0
    fi
    
    # Create repository
    local visibility_flag="--public"
    [[ "$REPO_VISIBILITY" == "private" ]] && visibility_flag="--private"
    
    if gh repo create "$repo_full_name" $visibility_flag --description "Test microservice for dependency updater" 2>&1 | grep -q "already exists"; then
        log_warning "Repository $repo_full_name already exists"
        return 0
    fi
    
    log_success "Created repository: $repo_full_name"
    return 0
}

# Function to create a service with git repo and branches
create_service() {
    local service_num="$1"
    local service_name="service-$(printf "%02d" $service_num)"
    
    log_info "Creating service: $service_name"
    
    mkdir -p "$service_name"
    cd "$service_name" || return 1
    
    # Initialize git repo
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Generate files for develop branch
    local develop_version="1.0.$service_num-SNAPSHOT-1"
    local common_develop_version="${COMMON_VERSION}-SNAPSHOT-1"
    
    generate_pom "$service_name" "$develop_version" "$common_develop_version"
    generate_release_txt "$develop_version"
    generate_release_notes "$service_name" "$develop_version"
    generate_readme "$service_name"
    generate_gitignore
    
    # Create initial commit
    git add .
    git commit -q -m "Initial commit for $service_name"
    
    # Create remote repository if requested
    if [[ "$CREATE_REMOTE_REPOS" == true ]]; then
        create_github_repo "$service_name"
    fi
    
    # Add remote origin
    local remote_url="https://${GIT_HOST}/${GIT_ORG}/${service_name}.git"
    git remote add origin "$remote_url"
    
    # Create develop branch (rename master/main to develop)
    current_branch=$(git branch --show-current)
    git branch -m "$current_branch" develop
    
    # Push develop branch if remote creation was requested
    if [[ "$CREATE_REMOTE_REPOS" == true ]]; then
        log_info "Pushing develop branch to remote..."
        if git push -u origin develop 2>&1; then
            log_success "Pushed develop branch"
        else
            log_error "Failed to push develop branch"
        fi
    fi
    
    # Create release branch
    git checkout -q -b release
    
    # Update files for release branch
    local release_version="1.0.$service_num-RC-1"
    local common_release_version="${COMMON_VERSION}-RC-1"
    
    generate_pom "$service_name" "$release_version" "$common_release_version"
    generate_release_txt "$release_version"
    generate_release_notes "$service_name" "$release_version"
    
    git add .
    git commit -q -m "Update for release branch"
    
    # Push release branch if remote creation was requested
    if [[ "$CREATE_REMOTE_REPOS" == true ]]; then
        log_info "Pushing release branch to remote..."
        if git push -u origin release 2>&1; then
            log_success "Pushed release branch"
        else
            log_error "Failed to push release branch"
        fi
    fi
    
    # Go back to develop branch
    git checkout -q develop
    
    # Add some uncommitted changes randomly to test stashing (30% chance)
    if (( RANDOM % 10 < 3 )); then
        echo "# Uncommitted changes test" >> README.md
        log_warning "Added uncommitted changes to $service_name"
    fi
    
    cd ..
    log_success "Service $service_name created successfully"
    echo ""
}

# Generate all services
log_info "Generating $NUM_SERVICES services..."
echo ""

for i in $(seq 1 $NUM_SERVICES); do
    create_service "$i"
done

echo ""
log_success "========================================="
log_success "Test environment created successfully!"
log_success "========================================="
log_info "Location: $(pwd)"
log_info "Services created: $NUM_SERVICES"
if [[ "$CREATE_REMOTE_REPOS" == true ]]; then
    log_success "Remote repositories created on GitHub"
    log_info "Organization: https://github.com/${GIT_ORG}"
fi
log_info ""
log_info "Each service has:"
log_info "  - Git repository initialized"
log_info "  - 'develop' branch with SNAPSHOT versions"
log_info "  - 'release' branch with RC versions"
log_info "  - pom.xml with ${COMMON_ARTIFACT_ID} dependency"
log_info "  - release.txt and release_notes.txt files"
if [[ "$CREATE_REMOTE_REPOS" == true ]]; then
    log_info "  - Remote repositories on GitHub"
    log_info "  - Both branches pushed to remote"
fi
log_info ""
log_info "To test the updater script, run:"
log_info "  cd $(pwd)"
log_info "  ../update_services.sh -a ${COMMON_ARTIFACT_ID} -v 2.0.0 -b both"
log_success "========================================="