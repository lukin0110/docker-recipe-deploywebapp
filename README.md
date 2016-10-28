# Build & deploy WebApps automatically with Docker

Modern WebApps, build with 
[React](https://facebook.github.io/react/) or 
[Angular2](https://angular.io/) for example, are setup with Node.js, 
Less or Sass and a lot of npm packages. Those apps require a build step 
before you deploy it on a webserver.

In an effort to fully automate the deployment flow of a WebApp, i've 
 hacked this recipe together with:
  
* [Docker](https://www.docker.com/)
* [AWS S3](https://aws.amazon.com/s3/)
* [Docker Hub](https://hub.docker.com/)
* [Docker Cloud](https://cloud.docker.com)

This recipe eliminates all manual steps to build and deploy WebApps. The 
 only thing you need to do is to push to your *master branch*, a few 
 minutes to app will be deployed.

## Build vs. production container

An image that contains Node.js, npm packages, etc can be quite big. You 
don't won't a container of **1GB** in production for just hosting 
static content. 

The recipe contains 2 Docker images:

* A [build image](Dockerfile): image contains all dependencies to develop 
& build a WebApp 
* A [production image](DockerfileNginx): simple image, based on 
[Linux Alpine](https://alpinelinux.org/), that contains the 
[Nginx](https://nginx.org/) webserver
    
Basic image sizes:

| image      | size     |
|------------|----------|
| build      | 697.2 MB |
| production | 55.67 MB |

*Notice the size of the build container*

## The solution

The development image creates an unique *artifact* (a tar.giz file) 
and uploads it to S3. The production image downloads and extracts the 
artifact in the Nginx data folder.

### Build image

The [build image](Dockerfile) installs all the npm packages and 
builds the WebApp. The important part of this this image is that it 
contains an 
[entrypoint](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#/entrypoint) 
to create a *tar.gz* file of the compiled WebApp and uploads it to S3. 

Entrypoint snippet:
```bash
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

This will create and upload the artifact to a S3 bucket 
*docker-tmp-release* (replace this with a bucket name of your own 
account). 

It's kind of ugly to upload a file during the build process of the 
docker image. But this allows you to use the 
[automated builds](https://docs.docker.com/docker-hub/builds/) 
feature of docker hub to build and upload the artifact when you push to 
the *master branch*.

### Production image

The [production image](DockerfileNginx) is being build with the 
automated builds feature of docker hub as well.

Snippet that downloads and extracts the artifact:
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

Add the [build image](Dockerfile) as repository link to the 
[production image](DockerfileNginx). When the build image is updated it 
will automatically trigger a rebuild of this Automated Build.

### Docker cloud

Docker cloud can be configured to automatically redeploy a container 
once an image has been updated. Set `autoredeploy: true`

Example stack file:
```yaml
app:
  image: lukin0110/webapp:latest
  autoredeploy: true
  ports:
    - "80:80"
  privileged: false
  restart: always
  target_num_containers: 1
  deployment_strategy: emptiest_node
```


## S3 Bucket

Add your AWS credentials in the [credentials file](.aws/credentials). 
Make sure they have access to S3.

In both containers you need to replace the bucket name 
*docker-tmp-release* to another bucket name. All bucket names on S3 are 
unique.
