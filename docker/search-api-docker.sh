#!/bin/bash

# Print a new line and the banner
echo
echo "==================== SEARCH-API ===================="

# The `absent_or_newer` checks if the copied src at docker/some-api/src directory exists 
# and if the source src directory is newer. 
# If both conditions are true `absent_or_newer` writes an error message 
# and causes script to exit with an error code.
function absent_or_newer() {
    if  [ \( -e $1 \) -a \( $2 -nt $1 \) ]; then
        echo "$1 is out of date"
        exit -1
    fi
}

function get_dir_of_this_script() {
    # This function sets DIR to the directory in which this script itself is found.
    # Thank you https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
    SCRIPT_SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SCRIPT_SOURCE" ]; do # resolve $SCRIPT_SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )"
        SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
        [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$DIR/$SCRIPT_SOURCE" # if $SCRIPT_SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )"
}

# Generate the build version based on git branch name and short commit hash and write into BUILD file
function generate_build_version() {
    GIT_BRANCH_NAME=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
    GIT_SHORT_COMMIT_HASH=$(git rev-parse --short HEAD)
    echo "BUILD version for Elasticsearch mapper_metadata.version: $GIT_BRANCH_NAME:$GIT_SHORT_COMMIT_HASH"
    # Clear the old BUILD version and write the new one
    truncate -s 0 ../BUILD
    echo $GIT_BRANCH_NAME:$GIT_SHORT_COMMIT_HASH >> ../BUILD
}

# Set the version environment variable for the docker build
# Version number is from the VERSION file
# Also remove newlines and leading/trailing slashes if present in that VERSION file
function export_version() {
    export SEARCH_API_VERSION=$(tr -d "\n\r" < ../VERSION | xargs)
    echo "SEARCH_API_VERSION: $SEARCH_API_VERSION"
}

if [[ "$1" != "localhost" && "$1" != "dev" && "$1" != "test" && "$1" != "stage" && "$1" != "prod" ]]; then
    echo "Unknown build environment '$1', specify one of the following: localhost|dev|test|stage|prod"
else
    if [[ "$2" != "check" && "$2" != "config" && "$2" != "build" && "$2" != "start" && "$2" != "stop" && "$2" != "down" ]]; then
        echo "Unknown command '$2', specify one of the following: check|config|build|start|stop|down"
    else
        get_dir_of_this_script
        echo 'DIR of script:' $DIR

        if [ "$2" = "check" ]; then
            # Bash array
            config_paths=(
                '../src/instance/app.cfg'
            )

            for pth in "${config_paths[@]}"; do
                if [ ! -e $pth ]; then
                    echo "Missing file (relative path to DIR of script) :$pth"
                    exit -1
                fi
            done

            absent_or_newer search-api/src ../src

            echo 'Checks complete, all good :)'
        elif [ "$2" = "config" ]; then
            export_version
            docker-compose -f docker-compose.yml -f docker-compose.$1.yml -p search-api config
        elif [ "$2" = "build" ]; then
            # Delete the copied source code dir if exists
            if [ -d "search-api/src" ]; then
                rm -rf search-api/src
            fi

            # Copy over the src folder
            cp -r ../src search-api/

            # Generate the build version
            generate_build_version
            
            export_version
            docker-compose -f docker-compose.yml -f docker-compose.$1.yml -p search-api build
        elif [ "$2" = "start" ]; then
            export_version
            docker-compose -f docker-compose.yml -f docker-compose.$1.yml -p search-api up -d
        elif [ "$2" = "stop" ]; then
            export_version
            docker-compose -f docker-compose.yml -f docker-compose.$1.yml -p search-api stop
        elif [ "$2" = "down" ]; then
            export_version
            docker-compose -f docker-compose.yml -f docker-compose.$1.yml -p search-api down
        fi
    fi
fi