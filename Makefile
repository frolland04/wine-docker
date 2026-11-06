.PHONY: all build up down clean

all: build

build:
	@./docker-build.sh

up:
	@./docker-start.sh $(BATCH)

down:
	@echo

clean:
	@rm -rf ./persist/devel ./persist/wine
