SHELL := /bin/bash
APPS  := $(HOME)/Applications/FinderSidebarIcons
LSR   := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: help manager icon examples status favorites symbols uninstall clean

help:
	@echo "make manager                build the Manager GUI (~/Applications/FinderSidebarIcons Manager.app)"
	@echo "make examples               install every icon in examples/*.json"
	@echo "make status                 list the Finder Sync extensions known to pkd"
	@echo "make favorites              list the real paths behind the Finder sidebar favorites"
	@echo "make symbols [HEX=#0083F1]  render a contact sheet of candidate SF Symbols"
	@echo "make uninstall              remove every helper app + its extension"
	@echo ""
	@echo "one icon:  make icon NAME=Projects TARGET=~/Projects SUFFIX=projects SYMBOL=hammer"

manager:
	@./scripts/build_manager.sh

# make icon NAME=.. TARGET=.. SUFFIX=.. SYMBOL=..  [SYMBOLMODE=0 SYSICNS=/path/icon.icns]
icon:
	@[ -n "$(NAME)" ] && [ -n "$(TARGET)" ] && [ -n "$(SUFFIX)" ] && [ -n "$(SYMBOL)" ] || \
		{ echo "usage: make icon NAME=Projects TARGET=~/Projects SUFFIX=projects SYMBOL=hammer"; exit 2; }
	@SYMBOLMODE="$(SYMBOLMODE)" ./scripts/build_icon_app.sh "$(NAME)" "$(TARGET)" "$(SUFFIX)" "$(SYMBOL)" "$(SYSICNS)"

examples:
	@./scripts/install_examples.sh

status:
	@pluginkit -m -A -D -p com.apple.FinderSync | grep findericon || echo "no sidebar icon extensions registered"

favorites:
	@swift scripts/favlist.swift list

symbols:
	@swift scripts/mknative.swift preview "$(or $(HEX),#0083F1)" /tmp/symbol-preview.png \
		chevron.left.forwardslash.chevron.right arrow.down.circle chair.lounge photo \
		hammer tray.full externaldrive folder.badge.gearshape && open /tmp/symbol-preview.png

uninstall:
	@for app in $(APPS)/*.app; do \
	  [ -e "$$app" ] || continue; \
	  pluginkit -r "$$app/Contents/PlugIns/SidebarSync.appex" 2>/dev/null || true; \
	  $(LSR) -u "$$app" 2>/dev/null || true; \
	  rm -rf "$$app"; echo "removed $$app"; \
	done
	@killall pkd 2>/dev/null || true; sleep 2; killall Finder 2>/dev/null || true

clean:
	@rm -rf build