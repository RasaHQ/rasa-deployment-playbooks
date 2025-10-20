trap 'if [ $? -ne 0 ]; then print_error "Script failed!" >&2; fi' EXIT

# Function to print text in green color
print_info() {
    printf "\033[36m--->\033[0m \033[1m%b\033[22m\n" "$1"
}

# Function to print text in red color
print_error() {
    printf "\033[1;31m---> %b\033[0m\n" "$1"
}

# Function to validate that all required variables are set
# Usage: validate_variables VAR1 VAR2 VAR3
validate_variables() {
    local var_names=("$@")

    # Print all variable values
    for name in "${var_names[@]}"; do
        print_info "$name: ${!name}"
    done

    # Check if any values are empty
    local validation_failed=false
    for name in "${var_names[@]}"; do
        if [[ -z "${!name}" ]]; then
            print_error "$name is not set!"
            validation_failed=true
        fi
    done

    if [[ "$validation_failed" == "true" ]]; then
        print_error "One or more required variable values are not set. Please set them and re-run this script."
        exit 1
    fi
}