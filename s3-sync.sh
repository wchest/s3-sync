#!/bin/bash

# Show example output when no arguments provided
usage() { echo "Usage: $0 [-c <path to configuration file>] [-p <path to s3cmd executable> ] [-o <override optional s3cmd defaults> ] [-d <perform a dry-run> ] [-l <path of optional logfile> ] <path to file/folders to be backed up> <name of s3://example-bucket>" 1>&2; exit 1; }

# Set default s3cfg location to s3cmd default
default_s3cfg="$HOME/.s3cfg"

# Set default s3cmd executable path
default_s3cmd_path=$(which s3cmd)

# Set default s3cmd options
default_s3cmd_options="--acl-private -s --server-side-encryption --cache-file $HOME/.cache/s3cmd/cache-file"

# Add CURL email support
# Set to false if not sending error messages
send_curl_mail=false
# mail_server=
# mail_from=
# mail_to=
# mail_subject=
# mail_api_key=

# Parse arguments
while getopts ":c:p:o:dl:" opt; do
    case $opt in
    c) # Manually specified configuration file
        # Set s3cfg var equal to passed in argument
        s3cfg=$OPTARG

        # Throw a fatal error if the specified file does not exist
        if [[ ! -e $s3cfg ]]; then 
            echo "FATAL: Specified file $s3cfg does not exist! Check the path and try again or run s3cmd --configure to create a .s3cfg file." >&2; exit 1;
        fi
        ;;
    p) # Manually specified s3cmd path
        s3cmd_path=$OPTARG

        # Throw a fatal error if the specified path to s3cmd does not exist
        if [[ ! -x $s3cmd_path ]]; then 
            echo "FATAL: Specified executable $OPTARG does not appear to exist! Check the path and try again." >&2; exit 1;
        fi
        ;;
    o) # String of all s3cmd options
        s3cmd_options="${OPTARG}"

        # Override defaults if options exist
        if [[ -z "${s3cmd_options}" ]]; then
            echo "FATAL: No options found! Check the options and try again." >&2; exit 1;
        fi
        ;;
    d) # Perform a dry-run
        # Set dry run variable
        s3cmd_dry_run="--dry-run"
        ;;
    l) # Add logging
        logfile=$OPTARG
        ;;
	\?) # Warn on invalid options
	    echo "WARNING: Invalid option: -$OPTARG"
	    usage
	    ;;
	:) # Warn for missing arguments
        echo "WARNING: Option $OPTARG requires an argument "
	    usage
	    ;;
    esac
done

# This tells getopts to move on to the next argument.
shift $((OPTIND-1))

# Setup logging
# If using logging it is strongly recommended to setup logrotate or some other method
# to prevent log files from accumulating and eating up disk space
if [[ -z $logfile && -e $logfile ]]; then
    logging_on=true
    exec >>$logfile 2>&1
else 
    if [[ ! -z $logfile ]]; then
        # Get containing directory of specified logfile target
        logfile_dir=$(dirname ${logfile})

        # Verify that containing directory exists and is accessible
        if [ -e $logfile_dir ]; then
            logging_on=true
            exec >>$logfile 2>&1
        else
            echo "Error: Logfile directory $logfile_dir does not exist or is not writable." >&2
        fi
    fi
fi

# Add to log if logging enabled
if [[ $logging_on ]]; then
    # Add starting message to logfile
    echo "-----------------------------------"
    echo "$(date +%FT%T%z): Starting sync of $1 to $2"
    echo ""
fi

# Use the default configuration if no config file specified
if [[ -z "$s3cfg" && -e $default_s3cfg ]]; then
    echo "INFO: Using default s3cmd configuration in $HOME/.s3cfg"
    s3cfg="$default_s3cfg"
fi

# Add flag for s3cfg
s3cfg="-c $s3cfg"

# Use the default s3cmd path if no path specified
if [[ -z "$s3cmd_path" && -x $default_s3cmd_path ]]; then
    echo "INFO: Using default s3cmd executable $default_s3cmd_path"
    s3cmd_path=$default_s3cmd_path
fi

# Throw error if no s3cmd path set by this point
if [[ -z "$s3cmd_path" ]]; then
    echo "FATAL: No s3cmd executable found. Check that s3cmd is installed by running which s3cmd or specify a path using the -p flag." >&2; exit 1;
fi

# Use the default s3cmd_options if none specified
if [[ -z "$s3cmd_options" ]]; then
    echo "INFO: Using default s3cmd options $default_s3cmd_options"
    s3cmd_options=$default_s3cmd_options
fi

# Check that sync target and path have been specified
if [[ $# != 2 ]]; then
    echo "FATAL: Missing target or S3 bucket arguments" 
    usage
fi

# Run s3cmd command with provided variables
$s3cmd_path sync $s3cfg $s3cmd_options $s3cmd_dry_run "$1" "$2"

# Add to log if enabled
if [[ $logging_on ]]; then
    # Add finished message to logfile
    echo ""
    echo "$(date +%FT%T%z): Finished sync of $1 to $2"
    echo "-----------------------------------"
fi

# Parse logfile for errors and send email update to $mail_to including log
if [[ $logging_on && $send_curl_mail == true ]]; then
    # Check to see if there were any errors or warnings in the logfile
    s3sync_warning_error_output="$(cat $logfile | awk 'BEGIN { warn_count=0; error_count=0; } /^WARN/ { print "<div>", $0, "</div>"; warn_count++; } /^ERROR/ { print "<div>", $0, "</div>"; error_count++; } END { print "<div><strong>Total Warnings:</strong> ", warn_count, "</div>"; print "<div><strong>Total Errors:</strong> ", error_count, "</div>" }' | tr -d "'")"

    # Base64 encode the logfile to send as an attachment
    base64_path=$(which base64)
    attachment_log=$(cat $logfile | $base64_path)

    # Only send email if errors or warnings found
    if [[ ! -z $s3sync_warning_error_output ]]; then
        curl $mail_server \
          -X POST \
          -H "Accept: application/json" \
          -H "Content-Type: application/json" \
          -H "X-Postmark-Server-Token: $mail_api_key" \
          -d "{From: '$mail_from', To: '$mail_to', Subject: '$1 - $mail_subject', HtmlBody: '$s3sync_warning_error_output', Attachments: [{ Name: 's3-sync-$(date).log', Content: '$attachment_log', ContentType: 'text/plain'}]}"
    fi
fi
# REMINDER: If logging is enabled, use logrotate or other methods to manage log size
