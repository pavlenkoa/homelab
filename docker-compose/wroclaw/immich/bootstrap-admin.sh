#!/bin/bash
set -euo pipefail

# Immich Bootstrap Script
# This script bypasses the "first user" setup screen by pre-creating an admin user
# that matches the OAuth credentials, avoiding the auto-registration conflict

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly RESET='\033[0m'

# Helper functions
log_info() { echo -e "${GREEN}✓${RESET} $1"; }
log_warn() { echo -e "${YELLOW}⚠️${RESET} $1"; }
log_error() { echo -e "${RED}✗${RESET} $1"; }

# Load environment variables
load_env() {
    local env_file="$1"
    if [[ -f "$env_file" ]]; then
        # Export variables from env file, skipping comments and empty lines
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^[[:space:]]*# ]] && continue  # Skip comments
            [[ -z "$key" ]] && continue                # Skip empty lines
            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            export "$key=$value"
        done < "$env_file"
        log_info "Loaded environment from $env_file"
    else
        log_warn "Environment file $env_file not found"
    fi
}

# Load environment variables
load_env "../.env.user"
load_env "../.env.generated"

# Validate required environment variables
validate_env() {
    local missing_vars=()
    
    [[ -z "${DOMAIN_NAME:-}" ]] && missing_vars+=("DOMAIN_NAME")
    [[ -z "${ADMIN_EMAIL:-}" ]] && missing_vars+=("ADMIN_EMAIL")
    [[ -z "${ADMIN_NAME:-Administrator}" ]] && ADMIN_NAME="Administrator"
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please configure them in .env.user"
        exit 1
    fi
    
    log_info "Environment validation passed"
    log_info "Domain: $DOMAIN_NAME"
    log_info "Admin email: $ADMIN_EMAIL"
    log_info "Admin name: $ADMIN_NAME"
}

# Generate secure temporary password
generate_temp_password() {
    # Generate a secure random password for temporary use
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
}

# Wait for Immich server to be ready
wait_for_immich() {
    log_info "Waiting for Immich server to be ready..."
    for i in {1..30}; do
        if curl -f http://localhost:2283/api/server/version > /dev/null 2>&1; then
            log_info "Immich server is ready"
            return 0
        fi
        echo "Waiting... ($i/30)"
        sleep 2
    done
    log_error "Timeout waiting for Immich server"
    exit 1
}

# Check if users already exist
check_existing_users() {
    local user_count
    user_count=$(docker exec immich_postgres psql -U immich -d immich -t -c 'SELECT COUNT(*) FROM users;' 2>/dev/null | tr -d ' ' || echo "0")
    echo "$user_count"
}

# Create admin user with generated password
create_admin_user() {
    local temp_password="$1"
    local response
    
    log_info "Creating admin user to bypass initial setup..."
    
    response=$(curl -s -X POST http://localhost:2283/api/auth/admin-sign-up \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"$ADMIN_EMAIL\",
            \"name\": \"$ADMIN_NAME\", 
            \"password\": \"$temp_password\"
        }")
    
    if echo "$response" | grep -q '"isAdmin":true'; then
        log_info "Admin user created successfully"
        # Extract and return user ID
        echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4
    else
        log_error "Failed to create admin user: $response"
        exit 1
    fi
}

# Login and get access token
get_access_token() {
    local temp_password="$1"
    local response
    
    response=$(curl -s -X POST http://localhost:2283/api/auth/login \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"$ADMIN_EMAIL\",
            \"password\": \"$temp_password\"
        }")
    
    if echo "$response" | grep -q '"accessToken"'; then
        log_info "Admin login successful"
        echo "$response" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4
    else
        log_error "Failed to login as admin: $response"
        exit 1
    fi
}

# Create API key for automation
create_api_key() {
    local access_token="$1"
    local response
    
    log_info "Creating API key for external library setup..."
    
    response=$(curl -s -X POST http://localhost:2283/api/api-keys \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $access_token" \
        -d '{
            "name": "External Library Automation",
            "permissions": ["library.create", "library.read", "library.update", "library.statistics"]
        }')
    
    if echo "$response" | grep -q '"secret"'; then
        log_info "API key created successfully"
        echo "$response" | grep -o '"secret":"[^"]*"' | cut -d'"' -f4
    else
        log_error "Failed to create API key: $response"
        exit 1
    fi
}

# Create external library for photos
create_external_library() {
    local api_key="$1"
    local user_id="$2"
    local response
    
    log_info "Creating external library for photos..."
    
    response=$(curl -s -X POST http://localhost:2283/api/libraries \
        -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -d "{
            \"name\": \"Photos\",
            \"ownerId\": \"$user_id\",
            \"importPaths\": [\"/usr/src/app/external/photos\"]
        }")
    
    if echo "$response" | grep -q '"id"'; then
        local library_id
        library_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        log_info "External library created successfully (ID: $library_id)"
        
        # Trigger initial scan
        log_info "Triggering initial library scan..."
        curl -s -X POST "http://localhost:2283/api/libraries/$library_id/scan" \
            -H "x-api-key: $api_key" > /dev/null
        log_info "Library scan initiated"
        
        return 0
    else
        log_warn "Failed to create external library: $response"
        return 1
    fi
}

# Disable password login for OAuth-only access
disable_password_login() {
    local api_key="$1"
    
    log_info "Disabling password login for OAuth-only access..."
    
    curl -s -X PUT "http://localhost:2283/api/system-config" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -d '{"passwordLogin": {"enabled": false}}' > /dev/null
    
    log_info "Password login disabled"
}

# Main execution
main() {
    echo "=== Immich Bootstrap Script ==="
    echo ""
    
    # Validate environment
    validate_env
    
    # Wait for Immich to be ready
    wait_for_immich
    
    # Check if users already exist
    local user_count
    user_count=$(check_existing_users)
    
    if [[ "$user_count" -eq 0 ]]; then
        # Generate secure temporary password
        local temp_password
        temp_password=$(generate_temp_password)
        log_info "Generated secure temporary password"
        
        # Create admin user
        local user_id
        user_id=$(create_admin_user "$temp_password")
        log_info "Admin user ID: $user_id"
        
        # Get access token
        local access_token
        access_token=$(get_access_token "$temp_password")
        
        # Create API key
        local api_key
        api_key=$(create_api_key "$access_token")
        
        # Create external library
        create_external_library "$api_key" "$user_id"
        
        # Disable password login
        disable_password_login "$api_key"
        
        echo ""
        log_info "OAuth auto-registration is now ready"
        echo ""
        echo "You can now:"
        echo "1. Access https://photos.$DOMAIN_NAME and click 'Login with Authelia'"
        echo "2. The OAuth flow will link your Authelia account to the admin user"
        echo "3. Password login is disabled, so OAuth is the only way to access"
        echo "4. External library 'Photos' is configured for /usr/src/app/external/photos"
        
        # Clear the temporary password from memory (security)
        unset temp_password
        
    else
        log_info "Users already exist ($user_count users found)"
        log_info "OAuth should work normally"
    fi
    
    echo ""
    log_info "Bootstrap completed successfully"
}

# Run main function
main "$@"