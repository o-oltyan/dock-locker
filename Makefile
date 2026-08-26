APP_NAME = DockLocker
BUNDLE_ID = com.octa.DockLocker
BUILD_DIR = build
APP = $(BUILD_DIR)/$(APP_NAME).app
BIN = .build/release/$(APP_NAME)
# Override with a stable self-signed identity to keep the Accessibility grant
# across rebuilds, e.g. `make app CODESIGN_IDENTITY="DockLocker Dev"`.
CODESIGN_IDENTITY ?= -

.PHONY: test build app run install reset-tcc clean

test:
	swift test

build:
	swift build -c release

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BIN) $(APP)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP)/Contents/Info.plist
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

# Ad-hoc signatures change every build, which can leave a stale Accessibility
# grant (toggle looks on, tap creation fails). This clears it.
reset-tcc:
	tccutil reset Accessibility $(BUNDLE_ID)

clean:
	rm -rf .build $(BUILD_DIR)
