APP_NAME = DockLocker
BUNDLE_ID = com.octa.DockLocker
BUILD_DIR = build
APP = $(BUILD_DIR)/$(APP_NAME).app
BIN = .build/apple/Products/Release/$(APP_NAME)
# Override with a stable self-signed identity to keep the Accessibility grant
# across rebuilds, e.g. `make app CODESIGN_IDENTITY="DockLocker Dev"`.
CODESIGN_IDENTITY ?= -

.PHONY: test build app run install zip reset-tcc clean

test:
	swift test

build:
	swift build -c release --arch arm64 --arch x86_64

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	plutil -lint $(APP)/Contents/Info.plist
	codesign --force --sign "$(CODESIGN_IDENTITY)" --identifier $(BUNDLE_ID) $(APP)
	codesign --verify $(APP)

run: app
	open $(APP)

install: app
	mkdir -p ~/Applications
	rm -rf ~/Applications/$(APP_NAME).app
	cp -R $(APP) ~/Applications/
	open ~/Applications/$(APP_NAME).app

# Release artifact: ditto preserves the bundle structure Finder expects.
zip: app
	ditto -c -k --keepParent $(APP) $(BUILD_DIR)/$(APP_NAME).zip

# Ad-hoc signatures change every build, which can leave a stale Accessibility
# grant (toggle looks on, tap creation fails). This clears it.
reset-tcc:
	tccutil reset Accessibility $(BUNDLE_ID)

clean:
	rm -rf .build $(BUILD_DIR)
