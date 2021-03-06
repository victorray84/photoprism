export GO111MODULE=on
GOIMPORTS=goimports
BINARY_NAME=photoprism
DOCKER_TAG=`date -u +%Y%m%d`

all: download dep js build
install: install-bin install-assets install-config
install-bin:
	scripts/build.sh prod /usr/local/bin/$(BINARY_NAME)
install-assets:
	mkdir -p /srv/photoprism/photos
	mkdir -p /srv/photoprism/cache
	mkdir -p /srv/photoprism/database
	cp -r assets/server /srv/photoprism
	cp -r assets/tensorflow /srv/photoprism
	find /srv/photoprism -name '.*' -type f -delete
install-config:
	mkdir -p /etc/photoprism
	test -e /etc/photoprism/photoprism.yml || cp -n configs/photoprism.yml /etc/photoprism/photoprism.yml
build:
	scripts/build.sh debug $(BINARY_NAME)
js:
	(cd frontend &&	yarn install --frozen-lockfile --prod)
	(cd frontend &&	env NODE_ENV=production npm run build)
start:
	go run cmd/photoprism/photoprism.go start
migrate:
	go run cmd/photoprism/photoprism.go migrate
test:
	go test -tags=slow -timeout 20m -v ./internal/... | scripts/colorize-tests.sh
test-fast:
	go test -timeout 5m -v ./internal/... | scripts/colorize-tests.sh
test-race:
	go test -tags=slow -race -timeout 60m -v ./internal/... | scripts/colorize-tests.sh
test-codecov:
	go test -tags=slow -timeout 30m -coverprofile=coverage.txt -covermode=atomic -v ./internal/...
	scripts/codecov.sh
test-coverage:
	go test -tags=slow -timeout 30m -coverprofile=coverage.txt -covermode=atomic -v ./internal/...
	go tool cover -html=coverage.txt -o coverage.html
clean:
	go clean
	rm -f $(BINARY_NAME)
download:
	scripts/download-inception.sh
deploy-photoprism:
	scripts/docker-build.sh photoprism $(DOCKER_TAG)
	scripts/docker-push.sh photoprism $(DOCKER_TAG)
deploy-demo:
	scripts/docker-build.sh demo $(DOCKER_TAG)
	scripts/docker-push.sh demo $(DOCKER_TAG)
deploy-development:
	scripts/docker-build.sh development $(DOCKER_TAG)
	scripts/docker-push.sh development $(DOCKER_TAG)
deploy-tensorflow:
	scripts/docker-build.sh tensorflow $(DOCKER_TAG)
	scripts/docker-push.sh tensorflow $(DOCKER_TAG)
deploy-darktable:
	DARKTABLE_VERSION="$(awk '$2 == "DARKTABLE_VERSION" { print $3; exit }' docker/darktable/Dockerfile)"
	scripts/docker-build.sh darktable $(DARKTABLE_VERSION)
	scripts/docker-push.sh darktable $(DARKTABLE_VERSION)
fmt:
	goimports -w internal cmd
	go fmt ./internal/... ./cmd/...
dep:
	go build -v ./...
	go mod tidy
upgrade:
	go get -u