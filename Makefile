.PHONY: build test app dmg release run install clean

APP_NAME := YouTube Music.app
DIST_APP := dist/$(APP_NAME)
VERSION ?= 1.0.0

build:
	swift build

test:
	chmod +x Scripts/run-tests.sh
	./Scripts/run-tests.sh

app:
	chmod +x Scripts/build-app.sh
	APP_VERSION=$(VERSION) ./Scripts/build-app.sh release

dmg:
	chmod +x Scripts/build-app.sh Scripts/build-release.sh
	APP_VERSION=$(VERSION) UNIVERSAL=1 ./Scripts/build-release.sh

release: dmg

run: app
	open "$(DIST_APP)"

install: app
	rm -rf "/Applications/$(APP_NAME)"
	cp -R "$(DIST_APP)" "/Applications/$(APP_NAME)"
	@echo "Installed to /Applications/$(APP_NAME)"

clean:
	swift package clean
	rm -rf dist
