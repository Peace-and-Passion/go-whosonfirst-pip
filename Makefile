prep:
	if test -d pkg; then rm -rf pkg; fi

self:   prep
	if test -d src/github.com/whosonfirst/go-whosonfirst-pip; then rm -rf src/github.com/whosonfirst/go-whosonfirst-pip; fi
	mkdir -p src/github.com/whosonfirst/go-whosonfirst-pip
	cp *.go src/github.com/whosonfirst/go-whosonfirst-pip/

deps:   self
	go get -u "github.com/whosonfirst/go-whosonfirst-geojson"
	go get -u "github.com/whosonfirst/go-whosonfirst-utils"
	go get -u "github.com/kellydunn/golang-geo"
	go get -u "github.com/dhconnelly/rtreego"

fmt:
	go fmt bin/*.go
	go fmt *.go

bin: 	self
	go build -o bin/index bin/index.go
	go build -o bin/index-csv bin/index-csv.go
	go build -o bin/pip-server bin/pip-server.go
