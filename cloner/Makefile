appname := glcloner
version := 1.0

all: build

build:
	GOOS=linux GOARCH=amd64 go build -o glcloner main.go
	docker build -t eurac/$(appname):$(version) .

push:
	docker login 
	docker push eurac/$(appname):$(version)

clean:
	rm -rf glcloner
	docker rmi -f eurac/$(appname):$(version)
