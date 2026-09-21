APP_NAME = DockLocker
BUNDLE_ID = com.octa.DockLocker
BUILD_DIR = build
APP = $(BUILD_DIR)/$(APP_NAME).app
BIN = .build/apple/Products/Release/$(APP_NAME)
# Signs with the self-signed certificate from scripts/make-signing-cert.sh when
# it's in the keychain, so the Accessibility grant survives rebuilds/updates;
# falls back to ad-hoc (grant breaks on every build) otherwise.
SIGNING_CERT = DockLocker Self-Signed
CODESIGN_IDENTITY ?= $(shell security find-certificate -c "$(SIGNING_CERT)" >/dev/null 2>&1 && echo "$(SIGNING_CERT)" || echo -)

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
	@codesign -d -r- $(APP) 2>&1 | grep designated

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

# Clears a stale Accessibility grant (toggle looks on, app isn't trusted) —
# what the app's own "Reset & Re-grant…" button runs.
reset-tcc:
	tccutil reset Accessibility $(BUNDLE_ID)

clean:
	rm -rf .build $(BUILD_DIR)
