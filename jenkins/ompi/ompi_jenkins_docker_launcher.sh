#!/bin/bash -eEx

# WORKSPACE_JENKINS_SCRIPTS - root folder for jenkins_scripts repo
if [ -z "${WORKSPACE_JENKINS_SCRIPTS}" ]
then
    echo "ERROR: WORKSPACE_JENKINS_SCRIPTS is not defined"
    exit 1
fi

# WORKSPACE_OMPI - root folder for OpenMPI source files
if [ -z "${WORKSPACE_OMPI}" ]
then
    echo "ERROR: WORKSPACE_OMPI is not defined"
    exit 1
fi

# BUILD_BUILDID is set by AzureCI
if [ -z "${BUILD_BUILDID}" ]
then
    echo "ERROR: BUILD_BUILDID is not defined"
    exit 1
fi

OMPI_CI_OS_NAME="centos"
OMPI_CI_OS_VERSION="7"
OMPI_CI_OFED="mofed-4.7-1.0.0.1"
OMPI_CI_IMAGE_NAME="${OMPI_CI_OS_NAME}_ompi:${BUILD_BUILDID}"

# Check that you are inside a docker container
cat /proc/1/cgroup

DOCKER_BUILD_CONTEXT_DIR=/tmp/ompi_build_docker_image_${BUILD_BUILDID}
rm -rf ${DOCKER_BUILD_CONTEXT_DIR}
mkdir -p ${DOCKER_BUILD_CONTEXT_DIR}

# Build Docker image
docker build \
    --no-cache \
    --network=host \
    --rm \
    --force-rm \
    --label=ompi \
    --build-arg OMPI_CI_OS=${OMPI_CI_OS_NAME}:${OMPI_CI_OS_VERSION} \
    --build-arg OMPI_CI_OFED=${OMPI_CI_OFED} \
    -f ${WORKSPACE_JENKINS_SCRIPTS}/jenkins/ompi/Dockerfile \
    -t ${OMPI_CI_IMAGE_NAME} \
    ${DOCKER_BUILD_CONTEXT_DIR}

rm -rf ${DOCKER_BUILD_CONTEXT_DIR}

docker images
docker ps -a

printenv

# Run OMPI CI scenarios (build and test)
docker run \
    -v /hpc/local:/hpc/local \
    -v /opt:/opt \
    --network=host \
    --uts=host \
    --ipc=host \
    --ulimit stack=67108864 \
    --ulimit memlock=-1 \
    --security-opt seccomp=unconfined \
    --cap-add=SYS_ADMIN \
    --device=/dev/infiniband/ \
    --env WORKSPACE=${WORKSPACE_OMPI} \
    ${OMPI_CI_IMAGE_NAME} \
    ${WORKSPACE_JENKINS_SCRIPTS}/jenkins/ompi/ompi_jenkins.sh

docker rmi ${OMPI_CI_IMAGE_NAME}
docker images
docker ps -a
