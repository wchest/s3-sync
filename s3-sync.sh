#!/bin/bash

# Show example output when no arguments provided
usage() { echo "Usage: $0 [-p <path to aws executable> ] [-o <aws options> ] [-d <perform a dry-run> ] [-l <path of optional logfile> ] <path to file/folders to be backed up> <name of s3://example-bucket>" 1>&2; exit 1; }

# Set default executable path
default_cmd_path=$(which aws) 

# Add CURL email support
# Set to false if not sending error messages
send_curl_mail=false
# mail_server=
# mail_from=
# mail_to=
# mail_subject=
# mail_api_key=

# Parse arguments
while getopts ":p:o:dl:" opt; do
    case $opt in
    p) # Manually specified path
        cmd_path=$OPTARG

        # Throw a fatal error if the specified path to does not exist
        if [[ ! -x $cmd_path ]]; then 
            echo "FATAL: Specified executable $cmd_path does not appear to exist! Check the path and try again." >&2; exit 1;
        fi
        ;;
    o) # String of all options
        options="${OPTARG}"
        ;;
    d) # Perform a dry-run
        # Set dry run variable
        dry_run="--dryrun"
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

# Use the default path if no path specified
if [[ -z "$cmd_path" && -x $default_cmd_path ]]; then
    echo "INFO: Using default executable $default_cmd_path"
    cmd_path=$default_cmd_path
fi

# Throw error if no path set by this point
if [[ -z "$cmd_path" ]]; then
    echo "FATAL: No aws executable found. Check that awscli is installed or specify a path using the -p flag." >&2; exit 1;
fi

# Use the default options if none specified
if [[ -z "$options" ]]; then
    echo "INFO: Using default options $default_options"
    options=$default_options
fi

# Check that sync target and path have been specified
if [[ $# != 2 ]]; then
    echo "FATAL: Missing target or S3 bucket arguments" 
    usage
fi

# Run command with provided variables
$cmd_path s3 sync "$1" "$2" $options $dry_run 

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
