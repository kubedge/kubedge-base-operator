
# Image URL to use all building/pushing image targets
COMPONENT        ?= kubedge-base-operator
VERSION_V1       ?= 0.1.13
DHUBREPO         ?= kubedge1/${COMPONENT}-dev
DOCKER_NAMESPACE ?= kubedge1
IMG_V1           ?= ${DHUBREPO}:v${VERSION_V1}

all: docker-build

setup:
ifndef GOPATH
	$(error GOPATH not defined, please define GOPATH. Run "go help gopath" to learn more about GOPATH)
endif
	# dep ensure

clean:
	rm -fr vendor
	rm -fr cover.out
	rm -fr build/_output
	rm -fr config/crds

# Run tests
unittest: setup fmt vet-v1
	echo "sudo systemctl stop kubelet"
	echo -e 'docker stop $$(docker ps -qa)'
	echo -e 'export PATH=$${PATH}:/usr/local/kubebuilder/bin'
	mkdir -p config/crds
	cp chart/templates/*v1alpha1* config/crds/
	go test ./pkg/... ./cmd/... -coverprofile cover.out

# Run go fmt against code
fmt: setup
	go fmt ./pkg/... ./cmd/...

# Run go vet against code
vet-v1: fmt
	go vet -composites=false -tags=v1 ./pkg/... ./cmd/...

# Generate code
generate: setup
	GO111MODULE=on controller-gen crd paths=./pkg/apis/kubedgeoperators/... crd:trivialVersions=true output:crd:dir=./chart/templates/ output:none
	GO111MODULE=on controller-gen object paths=./pkg/apis/kubedgeoperators/... output:object:dir=./pkg/apis/kubedgeoperators/v1alpha1 output:none

# Build the docker image
docker-build: fmt docker-build-v1

docker-build-v1: vet-v1
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o build/_output/bin/kubedge-base-operator -gcflags all=-trimpath=${GOPATH} -asmflags all=-trimpath=${GOPATH} -tags=v1 ./cmd/...
	docker build . -f build/Dockerfile -t ${IMG_V1}
	docker tag ${IMG_V1} ${DHUBREPO}:latest


# Push the docker image
docker-push: docker-push-v1

docker-push-v1:
	docker push ${IMG_V1}

# Run against the configured Kubernetes cluster in ~/.kube/config
install: install-v1

purge: setup
	helm delete --purge kubedge-base-operator

install-v1: docker-build-v1
	helm install --name kubedge-base-operator chart --set images.tags.operator=${IMG_V1}
