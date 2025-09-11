#!/bin/bash

# Wrapper of cat to remove all extra arguments

input=""
output=""
binary="cat"

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        -*)
            # Skip all options (including -D, -I, etc.)
            ;;
        *)
            if [[ -z "$input" ]]; then
                input="$arg"
            elif [[ -z "$output" ]]; then
                output="$arg"
            fi
            ;;
    esac
done

# If no input, read from stdin
if [[ -z "$input" ]]; then
    $binary -  # fallback: run cpp on stdin
    exit $?
fi

# If no output is given, write to stdout
if [[ -z "$output" ]]; then
    $binary "$input"
else
    $binary "$input" > "$output"
fi

