# Copyright IBM Corp All Rights Reserved.
# Copyright London Stock Exchange Group All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# -------------------------------------------------------------
# This makefile defines the following targets
#
#   - all (default) - builds all targets and runs all non-integration tests/checks
#   - checks - runs all non-integration tests/checks
#   - desk-check - runs linters and verify to test changed packages
#   - configtxgen - builds a native configtxgen binary
#   - configtxlator - builds a native configtxlator binary
#   - cryptogen  -  builds a native cryptogen binary
#   - idemixgen  -  builds a native idemixgen binary
#   - peer - builds a native fabric peer binary
#   - orderer - builds a native fabric orderer binary
#   - release - builds release packages for the host platform
#   - release-all - builds release packages for all target platforms
#   - publish-images - publishes release docker images to nexus3 or docker hub.
#   - unit-test - runs the go-test based unit tests
#   - verify - runs unit tests for only the changed package tree
#   - profile - runs unit tests for all packages in coverprofile mode (slow)
#   - test-cmd - generates a "go test" string suitable for manual customization
#   - gotools - installs go tools like golint
#   - linter - runs all code checks
#   - check-deps - check for vendored dependencies that are no longer used
#   - license - checks go source files for Apache license header
#   - native - ensures all native binaries are available
#   - docker[-clean] - ensures all docker images are available[/cleaned]
#   - docker-list - generates a list of docker images that 'make docker' produces
#   - peer-docker[-clean] - ensures the peer container is available[/cleaned]
#   - orderer-docker[-clean] - ensures the orderer container is available[/cleaned]
#   - tools-docker[-clean] - ensures the tools container is available[/cleaned]
#   - protos - generate all protobuf artifacts based on .proto files
#   - clean - cleans the build area
#   - clean-all - superset of 'clean' that also removes persistent state
#   - dist-clean - clean release packages for all target platforms
#   - unit-test-clean - cleans unit test state (particularly from docker)
#   - basic-checks - performs basic checks like license, spelling, trailing spaces and linter
#   - enable_ci_only_tests - triggers unit-tests in downstream jobs. Applicable only for CI not to
#     use in the local machine.
#   - docker-thirdparty - pulls thirdparty images (kafka,zookeeper,couchdb)
#   - docker-tag-latest - re-tags the images made by 'make docker' with the :latest tag
#   - docker-tag-stable - re-tags the images made by 'make docker' with the :stable tag
#   - help-docs - generate the command reference docs

ALPINE_VER ?= 3.9
BASE_VERSION = 2.0.0
PREV_VERSION = 1.4.0
CHAINTOOL_RELEASE ?= 1.1.3
BASEIMAGE_RELEASE = 0.4.14
JAVA_VER ?= 8
NODE_VER ?= 10

# Allow to build as a submodule setting the main project to
# the PROJECT_NAME env variable, for example,
# export PROJECT_NAME=hyperledger/fabric-test
ifeq ($(PROJECT_NAME),true)
PROJECT_NAME = $(PROJECT_NAME)/fabric
else
PROJECT_NAME = hyperledger/fabric
endif

BUILD_DIR ?= .build
NEXUS_REPO = nexus3.hyperledger.org:10001/hyperledger

EXTRA_VERSION ?= $(shell git rev-parse --short HEAD)
PROJECT_VERSION=$(BASE_VERSION)-snapshot-$(EXTRA_VERSION)

PKGNAME = github.com/$(PROJECT_NAME)
CGO_FLAGS = CGO_CFLAGS=" "
ARCH=$(shell go env GOARCH)
MARCH=$(shell go env GOOS)-$(shell go env GOARCH)

# defined in common/metadata/metadata.go
METADATA_VAR = Version=$(BASE_VERSION)
METADATA_VAR += CommitSHA=$(EXTRA_VERSION)
METADATA_VAR += BaseVersion=$(BASEIMAGE_RELEASE)
METADATA_VAR += BaseDockerLabel=$(BASE_DOCKER_LABEL)
METADATA_VAR += DockerNamespace=$(DOCKER_NS)
METADATA_VAR += BaseDockerNamespace=$(BASE_DOCKER_NS)

GO_VER = $(shell grep "GO_VER" ci.properties |cut -d'=' -f2-)
GO_LDFLAGS = $(patsubst %,-X $(PKGNAME)/common/metadata.%,$(METADATA_VAR))

GO_TAGS ?=

CHAINTOOL_URL ?= https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/chaintool-$(CHAINTOOL_RELEASE)/hyperledger-fabric-chaintool-$(CHAINTOOL_RELEASE).jar

export GO_LDFLAGS GO_TAGS

EXECUTABLES ?= go docker git curl
K := $(foreach exec,$(EXECUTABLES),\
	$(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH: Check dependencies")))

GOSHIM_DEPS = $(shell ./scripts/goListFiles.sh $(PKGNAME)/core/chaincode/shim)
PROTOS = $(shell git ls-files *.proto | grep -Ev 'vendor/|testdata/')
# No sense rebuilding when non production code is changed
PROJECT_FILES = $(shell git ls-files  | grep -v ^test | grep -v ^unit-test | \
	grep -v ^.git | grep -v ^examples | grep -v ^devenv | grep -v .png$ | \
	grep -v ^LICENSE | grep -v ^vendor )
RELEASE_TEMPLATES = $(shell git ls-files | grep "release/templates")
IMAGES = peer orderer baseos ccenv buildenv tools
RELEASE_PLATFORMS = windows-amd64 darwin-amd64 linux-amd64 linux-s390x linux-ppc64le
RELEASE_PKGS = configtxgen cryptogen idemixgen discover configtxlator peer orderer
RELEASE_IMAGES = peer orderer tools ccenv baseos

pkgmap.cryptogen      := $(PKGNAME)/cmd/cryptogen
pkgmap.idemixgen      := $(PKGNAME)/common/tools/idemixgen
pkgmap.configtxgen    := $(PKGNAME)/cmd/configtxgen
pkgmap.configtxlator  := $(PKGNAME)/cmd/configtxlator
pkgmap.peer           := $(PKGNAME)/cmd/peer
pkgmap.orderer        := $(PKGNAME)/orderer
pkgmap.block-listener := $(PKGNAME)/examples/events/block-listener
pkgmap.discover       := $(PKGNAME)/cmd/discover

include docker-env.mk

all: native docker checks

checks: basic-checks unit-test integration-test

basic-checks: license spelling trailing-spaces linter check-metrics-doc

desk-check: checks verify

help-docs: native
	@scripts/generateHelpDocs.sh

# Pull thirdparty docker images based on the latest baseimage release version
.PHONY: docker-thirdparty
docker-thirdparty:
	docker pull $(BASE_DOCKER_NS)/fabric-couchdb:$(BASE_DOCKER_TAG)
	docker tag $(BASE_DOCKER_NS)/fabric-couchdb:$(BASE_DOCKER_TAG) $(DOCKER_NS)/fabric-couchdb
	docker pull $(BASE_DOCKER_NS)/fabric-zookeeper:$(BASE_DOCKER_TAG)
	docker tag $(BASE_DOCKER_NS)/fabric-zookeeper:$(BASE_DOCKER_TAG) $(DOCKER_NS)/fabric-zookeeper
	docker pull $(BASE_DOCKER_NS)/fabric-kafka:$(BASE_DOCKER_TAG)
	docker tag $(BASE_DOCKER_NS)/fabric-kafka:$(BASE_DOCKER_TAG) $(DOCKER_NS)/fabric-kafka

.PHONY: spelling
spelling:
	@scripts/check_spelling.sh

.PHONY: license
license:
	@scripts/check_license.sh

.PHONY: trailing-spaces
trailing-spaces:
	@scripts/check_trailingspaces.sh

include gotools.mk

.PHONY: gotools
gotools: gotools-install

tools-docker: $(BUILD_DIR)/images/tools/$(DUMMY)

buildenv: $(BUILD_DIR)/images/buildenv/$(DUMMY)

baseos: $(BUILD_DIR)/images/baseos/$(DUMMY)

ccenv: $(BUILD_DIR)/images/ccenv/$(DUMMY)

.PHONY: check-go-version
check-go-version:
	@scripts/check_go_version.sh

.PHONY: peer
peer: check-go-version
peer: $(BUILD_DIR)/bin/peer
peer-docker: $(BUILD_DIR)/images/peer/$(DUMMY)

.PHONY: orderer
orderer: check-go-version
orderer: $(BUILD_DIR)/bin/orderer
orderer-docker: $(BUILD_DIR)/images/orderer/$(DUMMY)

.PHONY: configtxgen
configtxgen: GO_LDFLAGS=-X $(pkgmap.$(@F))/metadata.CommitSHA=$(EXTRA_VERSION)
configtxgen: $(BUILD_DIR)/bin/configtxgen

configtxlator: GO_LDFLAGS=-X $(pkgmap.$(@F))/metadata.CommitSHA=$(EXTRA_VERSION)
configtxlator: $(BUILD_DIR)/bin/configtxlator

cryptogen: GO_LDFLAGS=-X $(pkgmap.$(@F))/metadata.CommitSHA=$(EXTRA_VERSION)
cryptogen: $(BUILD_DIR)/bin/cryptogen

idemixgen: GO_LDFLAGS=-X $(pkgmap.$(@F))/metadata.CommitSHA=$(EXTRA_VERSION)
idemixgen: $(BUILD_DIR)/bin/idemixgen

discover: GO_LDFLAGS=-X $(pkgmap.$(@F))/metadata.Version=$(PROJECT_VERSION)
discover: $(BUILD_DIR)/bin/discover

.PHONY: integration-test
integration-test: gotool.ginkgo ccenv baseos docker-thirdparty
	./scripts/run-integration-tests.sh

unit-test: unit-test-clean peer-docker docker-thirdparty ccenv baseos
	./scripts/run-unit-tests.sh

unit-tests: unit-test

enable_ci_only_tests: unit-test

verify: export JOB_TYPE=VERIFY
verify: unit-test

profile: export JOB_TYPE=PROFILE
profile: unit-test

# Generates a string to the terminal suitable for manual augmentation / re-issue, useful for running tests by hand
test-cmd:
	@echo "go test -tags \"$(GO_TAGS)\""

docker: $(patsubst %,$(BUILD_DIR)/images/%/$(DUMMY), $(IMAGES))

native: peer orderer configtxgen cryptogen idemixgen configtxlator discover

linter: check-deps buildenv
	@echo "LINT: Running code checks.."
	@$(DRUN) $(DOCKER_NS)/fabric-buildenv:$(DOCKER_TAG) ./scripts/golinter.sh

check-deps: buildenv
	@echo "DEP: Checking for dependency issues.."
	@$(DRUN) $(DOCKER_NS)/fabric-buildenv:$(DOCKER_TAG) ./scripts/check_deps.sh

check-metrics-doc: buildenv
	@echo "METRICS: Checking for outdated reference documentation.."
	@$(DRUN) $(DOCKER_NS)/fabric-buildenv:$(DOCKER_TAG) ./scripts/metrics_doc.sh check

generate-metrics-doc: buildenv
	@echo "Generating metrics reference documentation..."
	@$(DRUN) $(DOCKER_NS)/fabric-buildenv:$(DOCKER_TAG) ./scripts/metrics_doc.sh generate

changelog:
	./scripts/changelog.sh v$(PREV_VERSION) v$(BASE_VERSION)

$(BUILD_DIR)/bin:
	@mkdir -p $@

$(BUILD_DIR)/bin/%: check-go-version $(PROJECT_FILES)
	@mkdir -p $(@D)
	@echo "$@"
	$(CGO_FLAGS) GOBIN=$(abspath $(@D)) go install -tags "$(GO_TAGS)" -ldflags "$(GO_LDFLAGS)" $(pkgmap.$(@F))
	@echo "Binary available as $@"
	@touch $@

$(BUILD_DIR)/images/baseos/$(DUMMY):
	@mkdir -p $(@D)
	$(eval TARGET = ${patsubst $(BUILD_DIR)/images/%/$(DUMMY),%,${@}})
	@echo "Docker:  building $(TARGET) image"
	$(DBUILD) -f images/peer/Dockerfile \
		--target base \
		--build-arg GO_VER=${GO_VER} --build-arg ALPINE_VER=${ALPINE_VER} \
		-t $(DOCKER_NS)/fabric-$(TARGET) images/peer
	docker tag $(DOCKER_NS)/fabric-$(TARGET) \
		$(DOCKER_NS)/fabric-$(TARGET):$(BASE_VERSION)
	docker tag $(DOCKER_NS)/fabric-$(TARGET) \
		$(DOCKER_NS)/fabric-$(TARGET):$(DOCKER_TAG)
	@touch $@

$(BUILD_DIR)/images/ccenv/$(DUMMY): BUILD_ARGS=--build-arg CHAINTOOL_RELEASE=${CHAINTOOL_RELEASE} \
	--build-arg JAVA_VER=${JAVA_VER} --build-arg NODE_VER=${NODE_VER}

$(BUILD_DIR)/images/%/$(DUMMY):
	@mkdir -p $(@D)
	$(eval TARGET = ${patsubst $(BUILD_DIR)/images/%/$(DUMMY),%,${@}})
	@echo "Docker:  building $(TARGET) image"
	$(DBUILD) -f images/$(TARGET)/Dockerfile \
		--build-arg GO_VER=${GO_VER} --build-arg ALPINE_VER=${ALPINE_VER} \
		${BUILD_ARGS} \
		-t $(DOCKER_NS)/fabric-$(TARGET) .
	docker tag $(DOCKER_NS)/fabric-$(TARGET) \
		$(DOCKER_NS)/fabric-$(TARGET):$(BASE_VERSION)
	docker tag $(DOCKER_NS)/fabric-$(TARGET) \
		$(DOCKER_NS)/fabric-$(TARGET):$(DOCKER_TAG)
	@touch $@

# builds release packages for the host platform
release: check-go-version $(patsubst %,release/%, $(MARCH))

# builds release packages for all target platforms
release-all: check-go-version $(patsubst %,release/%, $(RELEASE_PLATFORMS))

release/%: GO_LDFLAGS=-X $(pkgmap.$(@F))/metadata.CommitSHA=$(EXTRA_VERSION)

release/windows-amd64: GOOS=windows
release/windows-amd64: check-go-version $(patsubst %,release/windows-amd64/bin/%, $(RELEASE_PKGS)) release/windows-amd64/install

release/darwin-amd64: GOOS=darwin
release/darwin-amd64: check-go-version $(patsubst %,release/darwin-amd64/bin/%, $(RELEASE_PKGS)) release/darwin-amd64/install

release/linux-amd64: GOOS=linux
release/linux-amd64: check-go-version $(patsubst %,release/linux-amd64/bin/%, $(RELEASE_PKGS)) release/linux-amd64/install

release/%-amd64: GOARCH=amd64
release/linux-%: GOOS=linux

release/linux-s390x: GOARCH=s390x
release/linux-s390x: check-go-version $(patsubst %,release/linux-s390x/bin/%, $(RELEASE_PKGS)) release/linux-s390x/install

release/linux-ppc64le: GOARCH=ppc64le
release/linux-ppc64le: check-go-version $(patsubst %,release/linux-ppc64le/bin/%, $(RELEASE_PKGS)) release/linux-ppc64le/install

release/%/bin/configtxlator: $(PROJECT_FILES)
	@echo "Building $@ for $(GOOS)-$(GOARCH)"
	mkdir -p $(@D)
	$(CGO_FLAGS) GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(abspath $@) -tags "$(GO_TAGS)" -ldflags "$(GO_LDFLAGS)" $(pkgmap.$(@F))

release/%/bin/configtxgen: $(PROJECT_FILES)
	@echo "Building $@ for $(GOOS)-$(GOARCH)"
	mkdir -p $(@D)
	$(CGO_FLAGS) GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(abspath $@) -tags "$(GO_TAGS)" -ldflags "$(GO_LDFLAGS)" $(pkgmap.$(@F))

release/%/bin/cryptogen: $(PROJECT_FILES)
	@echo "Building $@ for $(GOOS)-$(GOARCH)"
	mkdir -p $(@D)
	$(CGO_FLAGS) GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(abspath $@) -tags "$(GO_TAGS)" -ldflags "$(GO_LDFLAGS)" $(pkgmap.$(@F))

release/%/bin/idemixgen: $(PROJECT_FILES)
	@echo "Building $@ for $(GOOS)-$(GOARCH)"
	mkdir -p $(@D)
	$(CGO_FLAGS) GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(abspath $@) -tags "$(GO_TAGS)" -ldflags "$(GO_LDFLAGS)" $(pkgmap.$(@F))

release/%/bin/discover: $(PROJECT_FILES)
	@echo "Building $@ for $(GOOS)-$(GOARCH)"
	mkdir -p $(@D)
	$(CGO_FLAGS) GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(abspath $@) -tags "$(GO_TAGS)" -ldflags "$(GO_LDFLAGS)" $(pkgmap.$(@F))

release/%/bin/orderer: GO_LDFLAGS = $(patsubst %,-X $(PKGNAME)/common/metadata.%,$(METADATA_VAR))

release/%/bin/orderer: $(PROJECT_FILES)
	@echo "Building $@ for $(GOOS)-$(GOARCH)"
	mkdir -p $(@D)
	$(CGO_FLAGS) GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(abspath $@) -tags "$(GO_TAGS)" -ldflags "$(GO_LDFLAGS)" $(pkgmap.$(@F))

release/%/bin/peer: GO_LDFLAGS = $(patsubst %,-X $(PKGNAME)/common/metadata.%,$(METADATA_VAR))

release/%/bin/peer: $(PROJECT_FILES)
	@echo "Building $@ for $(GOOS)-$(GOARCH)"
	mkdir -p $(@D)
	$(CGO_FLAGS) GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(abspath $@) -tags "$(GO_TAGS)" -ldflags "$(GO_LDFLAGS)" $(pkgmap.$(@F))

release/%/install: $(PROJECT_FILES)
	mkdir -p $(@D)/bin
	@cat $(@D)/../templates/get-docker-images.in \
		| sed -e 's|_NS_|$(DOCKER_NS)|g' \
		| sed -e 's|_ARCH_|$(GOARCH)|g' \
		| sed -e 's|_VERSION_|$(PROJECT_VERSION)|g' \
		| sed -e 's|_BASE_DOCKER_TAG_|$(BASE_DOCKER_TAG)|g' \
		> $(@D)/bin/get-docker-images.sh
		@chmod +x $(@D)/bin/get-docker-images.sh

.PHONY: dist
dist: dist-clean dist/$(MARCH)

dist-all: dist-clean $(patsubst %,dist/%, $(RELEASE_PLATFORMS))

dist/%: release/%
	mkdir -p release/$(@F)/config
	cp -r sampleconfig/*.yaml release/$(@F)/config
	cd release/$(@F) && tar -czvf hyperledger-fabric-$(@F).$(PROJECT_VERSION).tar.gz *

.PHONY: protos
protos: buildenv
	@$(DRUN) $(DOCKER_NS)/fabric-buildenv:$(DOCKER_TAG) ./scripts/compile_protos.sh

%-docker-list:
	$(eval TARGET = ${patsubst %-docker-list,%,${@}})
	@echo $(DOCKER_NS)/fabric-$(TARGET):$(DOCKER_TAG)

docker-list: $(patsubst %,%-docker-list, $(IMAGES))

%-docker-clean:
	$(eval TARGET = ${patsubst %-docker-clean,%,${@}})
	$(eval DOCKER_IMAGES = $(shell docker images --quiet --filter=reference='$(DOCKER_NS)/fabric-$(TARGET):$(ARCH)-$(BASE_VERSION)$(if $(EXTRA_VERSION),-snapshot-*,)'))
	[ -n "$(DOCKER_IMAGES)" ] && docker rmi -f $(DOCKER_IMAGES) || true
	-@rm -rf $(BUILD_DIR)/images/$(TARGET) ||:

docker-clean: $(patsubst %,%-docker-clean, $(IMAGES))

docker-tag-latest: $(IMAGES:%=%-docker-tag-latest)

%-docker-tag-latest:
	$(eval TARGET = ${patsubst %-docker-tag-latest,%,${@}})
	docker tag $(DOCKER_NS)/fabric-$(TARGET):$(DOCKER_TAG) $(DOCKER_NS)/fabric-$(TARGET):latest

docker-tag-stable: $(IMAGES:%=%-docker-tag-stable)

%-docker-tag-stable:
	$(eval TARGET = ${patsubst %-docker-tag-stable,%,${@}})
	docker tag $(DOCKER_NS)/fabric-$(TARGET):$(DOCKER_TAG) $(DOCKER_NS)/fabric-$(TARGET):stable

publish-images: $(RELEASE_IMAGES:%=%-publish-images) ## Build and publish docker images

%-publish-images:
	$(eval TARGET = ${patsubst %-publish-images,%,${@}})
	@docker login $(DOCKER_HUB_USERNAME) $(DOCKER_HUB_PASSWORD)
	@docker push $(DOCKER_NS)/fabric-$(TARGET):$(PROJECT_VERSION)

.PHONY: clean
clean: docker-clean unit-test-clean release-clean
	-@rm -rf $(BUILD_DIR)

.PHONY: clean-all
clean-all: clean gotools-clean dist-clean
	-@rm -rf /var/hyperledger/*
	-@rm -rf docs/build/

.PHONY: dist-clean
dist-clean:
	-@rm -rf release/windows-amd64/hyperledger-fabric-windows-amd64.$(PROJECT_VERSION).tar.gz
	-@rm -rf release/darwin-amd64/hyperledger-fabric-darwin-amd64.$(PROJECT_VERSION).tar.gz
	-@rm -rf release/linux-amd64/hyperledger-fabric-linux-amd64.$(PROJECT_VERSION).tar.gz
	-@rm -rf release/linux-s390x/hyperledger-fabric-linux-s390x.$(PROJECT_VERSION).tar.gz
	-@rm -rf release/linux-ppc64le/hyperledger-fabric-linux-ppc64le.$(PROJECT_VERSION).tar.gz

%-release-clean:
	$(eval TARGET = ${patsubst %-release-clean,%,${@}})
	-@rm -rf release/$(TARGET)

release-clean: $(patsubst %,%-release-clean, $(RELEASE_PLATFORMS))

.PHONY: unit-test-clean
unit-test-clean:
