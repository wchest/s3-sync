#!/bin/bash

# Show example output when no arguments provided
usage() { echo "Usage: $0 [-c <path to configuration file>] <path to file/folders to be backed up> <name of s3://example-bucket>" 1>&2; exit 1; }

# Set default s3cfg location to s3cmd default
default_s3cfg="$HOME/.s3cfg"

# Set default s3cmd executable path
default_s3cmd_path="s3cmd"

# Set default s3cmd options
default_s3cmd_options="--acl-private -s --server-side-encryption --cache-file $HOME/.cache/s3cmd/cache-file"

# Parse arguments
while getopts ":c:p:o:d" opt; do
    case $opt in
	c) # Manually specified configuration file
	    # Set s3cfg var equal to passed in argument
	    s3cfg=$OPTARG

        echo "s3cfg = $s3cfg"
	    
	    # Throw a fatal error if the specified file does not exist
	    if [ ! -e $s3cfg ]; then 
	        echo "Fatal: Specified file $s3cfg does not exist! Check the path and try again or run s3cmd --configure to create a .s3cfg file." >&2; exit 1;
	    fi
	    ;;
	p) # Manually specified s3cmd path
        s3cmd_path=$OPTARG

        # Throw a fatal error if the specified path to s3cmd does not exist
        if [ ! -x $s3cmd_path ]; then 
            echo "Fatal: Specified executable $OPTARG does not appear to exist! Check the path and try again." >&2; exit 1;
        fi
        ;;
    o) # String of all s3cmd options
        s3cmd_options="${OPTARG}"
        echo "s3cmd options = $s3cmd_options"
        
        # Override defaults if options exist
        if [ -z "${s3cmd_options}" ]; then
            echo "Fatal: No options found! Check the options and try again." >&2; exit 1;
        fi
        ;;
    d) # Perform a dry-run
        # Set dry run variable
        s3cmd_dry_run="--dry-run"
        ;;
	\?)
	    # Display error text for an invalid option
	    echo "Invalid option: -$OPTARG"
	    usage
	    ;;
	*)
        echo "FAILED"
	    # If none of these options match, display usage instructions
	    usage
	    ;;
    esac
done

# This tells getopts to move on to the next argument.
shift $((OPTIND-1))

# Use the default configuration if no config file specified
if [ -z "$s3cfg" ] && [ -e $default_s3cfg ]; then
    echo "Using default s3cmd configuration in $HOME/.s3cfg"
    s3cfg="-c $default_s3cfg"
else
    s3cfg="-c $s3cfg"
fi

# Use the default s3cmd path if no path specified
if [ -z "$s3cmd_path" ] && [ -x $default_s3cmd_path ]; then
    echo "Using default s3cmd executable $default_s3cmd_path"
    s3cmd_path=$default_s3cmd_path
fi

# Use the default s3cmd_options if none specified
if [ -z "$s3cmd_options" ]; then
    s3cmd_options=$default_s3cmd_options
fi

# Check that sync target and path have been specified
if [ $# -eq 2 ]; then
    echo "Two arguments passed!"
    echo "s3cmd_options = $s3cmd_options"

else
    usage
fi

# Run s3cmd command with provided variables
$s3cmd_path sync $s3cfg $s3cmd_options $s3cmd_dry_run $1 $2
