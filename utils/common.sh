trap 'if [ $? -ne 0 ]; then print_error "Script failed!" >&2; fi' EXIT

# Function to print text in green color
print_info() {
    printf "\033[32m%s\033[0m\n" "$1"
}

# Function to print text in red color
print_error() {
    printf "\033[31m%s\033[0m\n" "$1"
}