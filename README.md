# Build & deploy WebApps automatically with Docker

Modern WebApps, build with 
[React](https://facebook.github.io/react/) or 
[Angular2](https://angular.io/) for example, are setup with Node.js & a 
lot of npm packages. Those apps require a build step before you deploy 
it on a server.

In an effort to fully automate the deployment flow of a WebApp, i've 
 hacked this recipe together with:
  
* [Docker](https://www.docker.com/)
* [Docker Hub](https://hub.docker.com/)
* [AWS S3](https://aws.amazon.com/s3/)

## Build vs production container

A image that contains Node.js, npm packages, etc can be quite big, for
just hosting static content ... you don't won't a container of 1GB in 
production for just hosting static content. 

I've create 2 Docker images:

* [Build image](Dockerfile): image contains all dependencies to develop 
& build a WebApp 
* [Production image](DockerfileNginx): image simple contains the 
[Nginx](https://nginx.org/) webserver, based on Alpine
    
Basic image sizes:

| image      | size     |
|------------|----------|
| build      | 697.2 MB |
| production | 55.67 MB |

## The solution

The development image creates an unique artifact & uploads it S3. 
The production image downloads & extracts the artifact in the Nginx 
data folder.

### Build image

The [development image](Dockerfile) installs all the npm packages and 
builds the WebApp. They thing of this image is that it contains an 
entrypoint to create a *tar.gz* artifact file of the compiled WebApp & 
upload that artifact to S3. 

The entrypoint:
```bash
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
```

The entrypoint uses the latest commit hash, which is added by the 
[Dockerfile](Dockerfile), to add an unique version to the *tar.gz* file.

Here's the trick, the following 2 lines are added at the bottom of the 
image:

```bash
RUN /usr/local/bin/docker-entrypoint.sh create
RUN /usr/local/bin/docker-entrypoint.sh upload docker-tmp-release
```

This will upload the artifact to an S3 bucket *docker-tmp-release* 
(replace this with a bucket name of your own account). 

It's kind of ugly to upload a file during the build process of the 
docker image. But this allows you to use the 
[automated builds](https://docs.docker.com/docker-hub/builds/) 
feature of docker hub to build the artifact when you push to the 
*git master*.

### Production image

The [production image](DockerfileNginx) is being build with the 
automated builds of docker hub as well.

Snippet that downloads & extracts to artifact:
```bash
RUN mkdir -p /var/www \
    && cd /var/www \
    && ( \
      commit_hash=$( cat /commit_hash.txt | cut -c -8); \
      curl -O https://s3.amazonaws.com/docker-tmp-release/app_$commit_hash.tar.gz; \
      tar -xvzf /var/www/app_$commit_hash.tar.gz; \
      mv dist webapp; \
      rm app_$commit_hash.tar.gz; \
      date > webapp/version.txt; \
      echo $commit_hash >> webapp/version.txt; \
    )

```

### Automated builds

You need to link your Github or Bitbucket repository with Docker hub and 
create automated builds.

For the production image you need to switch off the 
*When active, builds will happen automatically on pushes* option. 

Add the production images as repository link. When the production image
is updated it will automatically trigger a rebuild of this Automated 
Build.

## S3 Bucket

In the [credentials file](.aws/credentials) you need to add your AWS 
credentials that have access to S3.

In both containers you need to replace the bucket name 
*docker-tmp-release* to another bucket name. All bucket names on S3 are 
unique.
  