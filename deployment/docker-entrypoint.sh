#!/bin/bash
set -e

# Define help message
show_help() {
    echo """
Usage: docker run <imagename> COMMAND

Commands

bash            : Start a bash shell
create          : Create a tarball (tar.gz)
upload <bucket> : Upload tarball to a S3 bucket
"""
}

case "$1" in
    bash)
        /bin/bash "${@:2}"
    ;;
    create)
        commit_hash=$( cat /commit_hash.txt | cut -c -8)
        tar -zcvf app_$commit_hash.tar.gz dist
    ;;
    upload)
        commit_hash=$( cat /commit_hash.txt | cut -c -8)
        # Create the bucket if it doesn't exist
        aws s3api create-bucket --bucket ${@:2}

        # Make the tarfile public readable. This avoids authentication problems in the DockerfileNginx file to download
        # the file. Otherwise the AWS CLI has to be installed and the goal is to keep that image small.
        #
        # It's not an issue to make the artifact public, because you can see the sourcecode anyway in the browser
        aws s3 cp app_$commit_hash.tar.gz s3://${@:2}/ --acl public-read
    ;;
    *)
        show_help
    ;;
esac
