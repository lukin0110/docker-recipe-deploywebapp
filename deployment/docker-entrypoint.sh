#!/bin/bash
set -e

# Define help message
show_help() {
    echo """
Usage: docker run <imagename> COMMAND

Commands

bash            : Start a bash shell
create          : Create a tarball (tar.gz)
upload <bucket> : Upload tarball to an S3 bucket
"""
}

case "$1" in
    bash)
        /bin/bash "${@:2}"
    ;;
    create)
        # The create script creates a tar.gz file
        commit_hash=$( cat /commit_hash.txt | cut -c -8)
        tar -zcvf app_$commit_hash.tar.gz dist
    ;;
    upload)
         # The release script uploads the .tar.gz file to S3
         # Create the bucket if it doesn't exist
        commit_hash=$( cat /commit_hash.txt | cut -c -8)
        aws s3api create-bucket --bucket ${@:2}
        aws s3 cp app_$commit_hash.tar.gz s3://${@:2}/ --acl public-read
    ;;
    *)
        show_help
    ;;
esac
