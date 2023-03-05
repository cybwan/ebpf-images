CTR_REGISTRY ?= cybwan
CTR_TAG      ?= latest
DOCKER_BUILDX_OUTPUT ?= type=registry
LOCAL_REGISTRY ?=local.registry

DOCKER_REGISTRY ?= docker.io/library
GOLANG_VERSION = 1.19
UBUNTU_VERSION ?= 20.04
KERNEL_VERSION ?= v5.4
DOCKER_BUILDX_PLATFORM ?= linux/amd64
LDFLAGS ?= "-s -w"

UBUNTU_TARGETS = ubuntu compiler base
DOCKER_UBUNTU_TARGETS = $(addprefix docker-build-interceptor-, $(UBUNTU_TARGETS))

GOLANG_TARGETS = golang
DOCKER_GOLANG_TARGETS = $(addprefix docker-build-interceptor-, $(GOLANG_TARGETS))

.PHONY: buildx-context
buildx-context:
	@if ! docker buildx ls | grep -q "^osm "; then docker buildx create --name osm --driver-opt network=host; fi

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
	-t $(CTR_REGISTRY)/osm-edge-interceptor:golang$(GOLANG_VERSION) \
	-f ./dockerfiles/Dockerfile.osm-edge-interceptor-golang \
	--build-arg DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	--build-arg GO_VERSION=$(GOLANG_VERSION) \
	.

.PHONY: docker-build-cross-interceptor-golang
docker-build-cross-interceptor-golang: DOCKER_BUILDX_PLATFORM=linux/amd64,linux/arm64
docker-build-cross-interceptor-golang: docker-build-interceptor-golang

.PHONY: docker-build-cross-interceptor-golang
docker-build-cross-interceptor-golang: DOCKER_BUILDX_PLATFORM=linux/amd64,linux/arm64
docker-build-cross-interceptor-golang: docker-build-interceptor-golang


.PHONY: docker-build-osm
docker-build-osm: buildx-context $(DOCKER_UBUNTU_TARGETS) $(DOCKER_GOLANG_TARGETS)

.PHONY: docker-build-cross-osm
docker-build-cross-osm: DOCKER_BUILDX_PLATFORM=linux/amd64,linux/arm64
docker-build-cross-osm: docker-build-osm

.PHONY: trivy-ci-setup
trivy-ci-setup:
	wget https://github.com/aquasecurity/trivy/releases/download/v0.23.0/trivy_0.23.0_Linux-64bit.tar.gz
	tar zxvf trivy_0.23.0_Linux-64bit.tar.gz
	echo $$(pwd) >> $(GITHUB_PATH)

# Show all vulnerabilities in logs
trivy-scan-ubuntu-verbose-%: NAME=$(@:trivy-scan-ubuntu-verbose-%=%)
trivy-scan-ubuntu-verbose-%:
	trivy image "$(CTR_REGISTRY)/osm-edge-interceptor:$(NAME)$(UBUNTU_VERSION)"

# Exit if vulnerability exists
trivy-scan-ubuntu-fail-%: NAME=$(@:trivy-scan-ubuntu-fail-%=%)
trivy-scan-ubuntu-fail-%:
	trivy image --exit-code 1 --ignore-unfixed --severity MEDIUM,HIGH,CRITICAL "$(CTR_REGISTRY)/osm-edge-interceptor:$(NAME)$(UBUNTU_VERSION)"

# Show all vulnerabilities in logs
trivy-scan-golang-verbose-%: NAME=$(@:trivy-scan-golang-verbose-%=%)
trivy-scan-golang-verbose-%:
	trivy image "$(CTR_REGISTRY)/osm-edge-interceptor:$(NAME)$(GOLANG_VERSION)"

# Exit if vulnerability exists
trivy-scan-golang-fail-%: NAME=$(@:trivy-scan-golang-fail-%=%)
trivy-scan-golang-fail-%:
	trivy image --exit-code 1 --ignore-unfixed --severity MEDIUM,HIGH,CRITICAL "$(CTR_REGISTRY)/osm-edge-interceptor:$(NAME)$(GOLANG_VERSION)"


.PHONY: trivy-scan-images trivy-scan-images-fail trivy-scan-images-verbose
trivy-scan-images-verbose: $(addprefix trivy-scan-ubuntu-verbose-, $(UBUNTU_TARGETS)) $(addprefix trivy-scan-golang-verbose-, $(GOLANG_TARGETS))
trivy-scan-images-fail: $(addprefix trivy-scan-ubuntu-fail-, $(UBUNTU_TARGETS)) $(addprefix trivy-scan-golang-fail-, $(GOLANG_TARGETS))
trivy-scan-images: trivy-scan-images-verbose trivy-scan-images-fail

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