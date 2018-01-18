#!/bin/bash

# Usage
# LOG_LEVEL=INFO ./remoteSynch.sh

# Enumerating the available logging levels
declare -A LOGGING_LEVELS=(["INFO"]="1" ["ERROR"]="2" ["DEBUG"]="3" ["TRACE"]="4" )

# DEBUG
# INFO
if [ "$LOG_LEVEL" == "" ]; then 
	LOG_LEVEL=DEBUG
fi 

LOCAL_SYNCH_DIR=/your/local/dir
REMOTE_SYNCH_DIR=/your/remote/dir
REMOTE_USER=ssh_user
REMOTE_SERVER=ssh_host

# File output
LOG_DIR=/your/local/logs
SYNCH_LOG_FILE=$LOG_DIR/sync_$(date +"%F").log
RSYNCH_LOG_FILE=$LOG_DIR/rsync_$(date +"%F").log
UNSYNCHED_LOG_FILE=$LOG_DIR/unsyncd_$(date +"%F").log

# I haven't managed to figure out how to dynamically replace the REMOTE_SYNCH_DIR
# and have the remote shelling invokation work correctly
REMOTE_COMMAND='for f in '$REMOTE_SYNCH_DIR'/*; do 
    # We only want to synchronise directories
    if [[ -d $f ]]; then
       	# Only the filename ( we dont want the path)
	echo "${f##*/}|"
    fi
done'

# Logs messages as the designated type to $LOG_DIR
# Usage logger 
#	param : LogLevel 
#	param : Message 
# Loglevel:
# 	DEBUG
# 	INFO	
function logger {
	if [[ ${LOGGING_LEVELS[$1]} -eq  ${LOGGING_LEVELS[$LOG_LEVEL]} || ${LOGGING_LEVELS[$1]} -lt  ${LOGGING_LEVELS[$LOG_LEVEL]} ]]; then
		echo `date +"%F %H:%M:%S"` " $*" >> $SYNCH_LOG_FILE
	fi
}

# Enumerates all the files in the provided directory and creates a filelist called exclude.txt
# Each line in the resultant file will contain a wildcard name (*myWordDoc* for a file named myWordDoc.doc) for each file in the directory
# Usage buildExlcudeFileList
#	param : directory_path
function buildExcludeFileList {
	logger DEBUG "Invoking buildExcludeFileList with params $1"
	find "$1" -mindepth 2 -print | cut -d/ -f7 | cut -d'.' -f1,3 | while read i; do echo *$i* ; done > "$1/exclude.txt"

	# I only ever want to cat this file when running in TRACE
	if [ "$LOG_LEVEL" == "TRACE" ]; then 
		logger TRACE exclude.txt contains : $(cat "$1/exclude.txt")
	fi 

}

function synchronise {
	#logger INFO "Invoking rsync with params : -rshuILv --progress --log-file=$RSYNCH_LOG_FILE --exclude-from=\"$LOCAL_SYNCH_DIR/$1/exclude.txt\"  $REMOTE_USER@$REMOTE_SERVER:\"$REMOTE_SYNCH_DIR/$1/\" \"$LOCAL_SYNCH_DIR/$1\""
	logger TRACE $(env)
	/usr/local/bin/rsync -rshuILv --progress --log-file=$RSYNCH_LOG_FILE --exclude-from="$LOCAL_SYNCH_DIR/$1/exclude.txt" $REMOTE_USER@$REMOTE_SERVER:"$REMOTE_SYNCH_DIR/$1/" "$LOCAL_SYNCH_DIR/$1"
	exit_code=$?
	if [ "$exit_code" != "0" ];
	then
		logger ERROR Running as $(whoami) 
		logger ERROR "Rsync failed"
		logger ERROR "Experienced error $exit_code"
	else
		logger INFO "Synchronised $1"
	fi

}


# Change the delimeter (to be '|') otherwise the array splits by ' '
IFS_OLD=$IFS
IFS="|"

# Build an array of filenames from the result of a remote ssh call
logger INFO "Invoking ssh"
logger DEBUG "ssh $REMOTE_USER@$REMOTE_SERVER $REMOTE_COMMAND"

# Still haven't figured out how to pass the remote dir as a parameter
# Look at variable $REMOTE_COMMAND
remoteFiles=(`ssh $REMOTE_USER@$REMOTE_SERVER '
for f in /your/remote/dir*; do
    # We only want to synchronise directories
    if [[ -d $f ]]; then
       	# Only the filename ( we dont want the path)
	echo "${f##*/}|"
    fi
done
'`) 

# Arrays appear to be space delimetered.  Thus we need to restore the ' ' delimeter otherwise we can't split the array
# Restore the old delimeter
IFS=$IFS_OLD

logger INFO "Returning ssh"

# If we have the same directory in our list locally, then call a rsync thread
# I've decided to go with blocking calls as throtteling threads felt like overkill
for directory in "${remoteFiles[@]}"; do

	directoryName="$(echo $directory)"
	logger TRACE "Remote directory name : $directoryName"

        if [[ -d "$LOCAL_SYNCH_DIR/$directoryName" ]]; then
		logger DEBUG "Matched local dir $LOCAL_SYNCH_DIR/$directoryName"
		buildExcludeFileList "$LOCAL_SYNCH_DIR/$directoryName"
		synchronise "$directoryName"
        else
                echo not synching directory $LOCAL_SYNCH_DIR/$directoryName >> $UNSYNCHED_LOG_FILE 
    	fi
	
	logger INFO ""
done	
