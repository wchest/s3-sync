#!/bin/bash

# Show example output when no arguments provided
usage() { echo "Usage: $0 [-c <path to configuration file>] <path to file/folders to be backed up> <name of s3://example-bucket>" 1>&2; exit 1; }

# Set default s3cfg location to s3cmd default
default_s3cfg="$HOME/.s3cfg"

# Parse arguments
while getopts ":c:" opt; do
    case $opt in
	c)
	    # Set s3cfg var equal to passed in argument
	    s3cfg=$OPTARG
	    
	    # Throw a fatal error if the specified file does not exist
	    if [ ! -e $s3cfg ]; then 
	        echo "Fatal: Specified file $s3cfg does not exist! Check the path and try again or run s3cmd --configure to create a .s3cfg file" >&2; exit 1;
	    fi
	    ;;
	\?)
	    # Display error text for an invalid option
	    echo "Invalid option: -$OPTARG"
	    usage
	    ;;
	*)
	    # If none of these options match, display usage instructions
	    usage
	    ;;
    esac
done

# Use the default configuration if no config file passed in
if [ -z "$s3cfg" ] && [ -e $default_s3cfg ]; then
    echo "Using default s3cmd configuration in $HOME/.s3cfg"
    s3cfg=$default_s3cfg
else
    # Throw fatal error if no config file passed in and no default config exists
    echo "Fatal: Unable to determine s3cmd configuration location. Run s3cmd --configure or pass in a proper .s3cfg file" >&2; exit 1;
fi

# s3cmd configuration file location
echo "The configuration file is loacated at $s3cfg"
