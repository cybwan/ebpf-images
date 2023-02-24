CTR_REGISTRY ?= cybwan
CTR_TAG      ?= latest
DOCKER_BUILDX_OUTPUT ?= type=registry
LOCAL_REGISTRY ?=local.registry

DOCKER_REGISTRY ?= docker.io/library
DOCKER_GO_VERSION = 1.19
UBUNTU_VERSION ?= 22.04
KERNEL_VERSION ?= v5.15
DOCKER_BUILDX_PLATFORM ?= linux/amd64
LDFLAGS ?= "-s -w"

OSM_TARGETS = ubuntu compiler golang base
DOCKER_OSM_TARGETS = $(addprefix docker-build-interceptor-, $(OSM_TARGETS))

.PHONY: buildx-context
buildx-context:
	@if ! docker buildx ls | grep -q "^osm "; then docker buildx create --name osm --driver-opt network=host; fi

$(foreach target,$(OSM_TARGETS),$(eval docker-build-interceptor-$(target): buildx-context))

.PHONY: docker-build-interceptor-ubuntu
docker-build-interceptor-ubuntu:
	docker buildx build --builder osm \
	--platform=$(DOCKER_BUILDX_PLATFORM) \
	-o $(DOCKER_BUILDX_OUTPUT) \
	-t $(CTR_REGISTRY)/osm-edge-interceptor:ubuntu$(UBUNTU_VERSION) \
	-f ./dockerfiles/Dockerfile.osm-edge-interceptor-ubuntu \
	--build-arg DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
	.

.PHONY: docker-build-cross-interceptor-ubuntu
docker-build-cross-interceptor-ubuntu: DOCKER_BUILDX_PLATFORM=linux/amd64,linux/arm64
docker-build-cross-interceptor-ubuntu: docker-build-interceptor-ubuntu

.PHONY: docker-build-interceptor-compiler
docker-build-interceptor-compiler:
	docker buildx build --builder osm \
	--platform=$(DOCKER_BUILDX_PLATFORM) \
	-o $(DOCKER_BUILDX_OUTPUT) \
	-t $(CTR_REGISTRY)/osm-edge-interceptor:compiler$(UBUNTU_VERSION) \
	-f ./dockerfiles/Dockerfile.osm-edge-interceptor-compiler \
	--build-arg CTR_REGISTRY=$(CTR_REGISTRY) \
	--build-arg CTR_TAG=$(UBUNTU_VERSION) \
	--build-arg KERNEL_VERSION=$(KERNEL_VERSION) \
	.

.PHONY: docker-build-cross-interceptor-compiler
docker-build-cross-interceptor-compiler: DOCKER_BUILDX_PLATFORM=linux/amd64,linux/arm64
docker-build-cross-interceptor-compiler: docker-build-interceptor-compiler

.PHONY: docker-build-interceptor-base
docker-build-interceptor-base:
	docker buildx build --builder osm \
	--platform=$(DOCKER_BUILDX_PLATFORM) \
	-o $(DOCKER_BUILDX_OUTPUT) \
	-t $(CTR_REGISTRY)/osm-edge-interceptor:base$(UBUNTU_VERSION) \
	-f ./dockerfiles/Dockerfile.osm-edge-interceptor-base \
	--build-arg CTR_REGISTRY=$(CTR_REGISTRY) \
	--build-arg CTR_TAG=$(UBUNTU_VERSION) \
	.

.PHONY: docker-build-cross-interceptor-base
docker-build-cross-interceptor-base: DOCKER_BUILDX_PLATFORM=linux/amd64,linux/arm64
docker-build-cross-interceptor-base: docker-build-interceptor-base

.PHONY: docker-build-interceptor-golang
docker-build-interceptor-golang:
	docker buildx build --builder osm \
	--platform=$(DOCKER_BUILDX_PLATFORM) \
	-o $(DOCKER_BUILDX_OUTPUT) \
	-t $(CTR_REGISTRY)/osm-edge-interceptor:golang$(DOCKER_GO_VERSION) \
	-f ./dockerfiles/Dockerfile.osm-edge-interceptor-golang \
	--build-arg DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	--build-arg GO_VERSION=$(DOCKER_GO_VERSION) \
	.

.PHONY: docker-build-cross-interceptor-golang
docker-build-cross-interceptor-golang: DOCKER_BUILDX_PLATFORM=linux/amd64,linux/arm64
docker-build-cross-interceptor-golang: docker-build-interceptor-golang

.PHONY: docker-build-cross-interceptor-golang
docker-build-cross-interceptor-golang: DOCKER_BUILDX_PLATFORM=linux/amd64,linux/arm64
docker-build-cross-interceptor-golang: docker-build-interceptor-golang


.PHONY: docker-build-osm
docker-build-osm: $(DOCKER_OSM_TARGETS)

.PHONY: docker-build-cross-osm
docker-build-cross-osm: DOCKER_BUILDX_PLATFORM=linux/amd64,linux/arm64
docker-build-cross-osm: docker-build-osm

load-images:
	docker pull ubuntu:20.04
	docker pull ubuntu:22.04
	docker pull golang:1.19
	docker pull golang:1.20
	docker pull curlimages/curl:latest
	docker pull istio/examples-helloworld-v1:latest
	docker pull istio/examples-helloworld-v2:latest
	docker tag ubuntu:20.04 $(LOCAL_REGISTRY)/ubuntu:20.04
	docker tag ubuntu:22.04 $(LOCAL_REGISTRY)/ubuntu:22.04
	docker tag golang:1.19 $(LOCAL_REGISTRY)/golang:1.19
	docker tag golang:1.20 $(LOCAL_REGISTRY)/golang:1.20
	docker tag curlimages/curl:latest $(LOCAL_REGISTRY)/curlimages/curl:latest
	docker tag istio/examples-helloworld-v1:latest $(LOCAL_REGISTRY)/istio/examples-helloworld-v1:latest
	docker tag istio/examples-helloworld-v2:latest $(LOCAL_REGISTRY)/istio/examples-helloworld-v2:latest
	docker push $(LOCAL_REGISTRY)/ubuntu:20.04
	docker push $(LOCAL_REGISTRY)/ubuntu:22.04
	docker push $(LOCAL_REGISTRY)/golang:1.19
	docker push $(LOCAL_REGISTRY)/golang:1.20
	docker push $(LOCAL_REGISTRY)/curlimages/curl:latest
	docker push $(LOCAL_REGISTRY)/istio/examples-helloworld-v1:latest
	docker push $(LOCAL_REGISTRY)/istio/examples-helloworld-v2:latest
	docker rmi $(LOCAL_REGISTRY)/ubuntu:20.04
	docker rmi $(LOCAL_REGISTRY)/ubuntu:22.04
	docker rmi $(LOCAL_REGISTRY)/golang:1.19
	docker rmi $(LOCAL_REGISTRY)/golang:1.20
	docker rmi $(LOCAL_REGISTRY)/curlimages/curl:latest
	docker rmi $(LOCAL_REGISTRY)/istio/examples-helloworld-v1:latest
	docker rmi $(LOCAL_REGISTRY)/istio/examples-helloworld-v2:latest
	docker rmi ubuntu:20.04
	docker rmi ubuntu:22.04
	docker rmi golang:1.19
	docker rmi golang:1.20
	docker rmi curlimages/curl:latest
	docker rmi istio/examples-helloworld-v1:latest
	docker rmi istio/examples-helloworld-v2:latest