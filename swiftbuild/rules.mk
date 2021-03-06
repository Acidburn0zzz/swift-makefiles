include $(TOPSRCDIR)/swiftbuild/checkconfig.mk

ifndef OBJS
_OBJS = $(patsubst %.swift,%.o,$(SOURCES))
OBJS    = $(strip $(_OBJS))
_SWIFTMODULES = $(patsubst %.swift,%~partial.swiftmodule,$(SOURCES))
SWIFTMODULES = $(strip $(_SWIFTMODULES))
endif

ifdef APP_NAME
OBJS += main.o
.NOTPARALLEL: main.o
endif

ifdef APP_BUNDLE_NAME
APP_BUNDLE           = $(OBJDIR)/$(APP_BUNDLE_NAME).app
APP_BUNDLE_CONTENTS  = $(APP_BUNDLE)/Contents
APP_BUNDLE_MACOS     = $(APP_BUNDLE_CONTENTS)/MacOS
APP_BUNDLE_RESOURCES = $(APP_BUNDLE_CONTENTS)/Resources
endif

IMPORTS += -I $(OBJDIR)/modules

build: dirs $(OBJS)
		$(shell mkdir -p $(OBJDIR)/modules)
ifdef MODULE_NAME
ifdef SOURCES
		# building $(MODULE_NAME).swiftmodule from partial swiftmodules
		@$(SWIFT) $(CFLAGS) $(IMPORTS) -emit-module -parse-as-library -emit-module-path $(OBJDIR)/modules/$(MODULE_NAME).swiftmodule -module-name $(MODULE_NAME) -L $(OBJDIR)/modules $(LIBS) -sdk $(SDK_PATH) $(SWIFTMODULES)
		# building lib$(MODULE_NAME).dylib
		@$(CXX) -dynamiclib -undefined suppress -flat_namespace -L $(TOOLCHAIN_PATH) $(OBJS) -o lib$(MODULE_NAME).dylib 
		# fixing rpath in lib$(MODULE_NAME).dylib
	  @install_name_tool -id @rpath/lib$(MODULE_NAME).dylib lib$(MODULE_NAME).dylib
		# installing lib$(MODULE_NAME).dylib in $(OBJDIR)
		@install lib$(MODULE_NAME).dylib $(OBJDIR)
endif # SOURCES
endif # MODULE_NAME
ifdef APP_NAME
		# creating executable $(APP_NAME) in $(OBJDIR)
		@$(LD) $(LDFLAGS) -o $(OBJDIR)/$(APP_NAME) -L$(TOOLCHAIN_PATH) -Lbin $(LIBS) -rpath @executable_path main.o
ifdef APP_BUNDLE_NAME
		#####################################################
		# creating $(APP_BUNDLE)
		@rm -fr $(APP_BUNDLE_NAME).app
		@mkdir -p $(APP_BUNDLE_MACOS)
		@mkdir -p $(APP_BUNDLE_RESOURCES)
		@cp Info.plist $(APP_BUNDLE_CONTENTS)
		@cp PkgInfo $(APP_BUNDLE_CONTENTS)
		@cp $(APP_NAME).icns $(APP_BUNDLE_RESOURCES)
		@if [ -d "Resources" ]; then cp -fr Resources/* $(APP_BUNDLE_RESOURCES); fi
		@cp $(OBJDIR)/$(APP_NAME) $(APP_BUNDLE_MACOS)
		@cp $(OBJDIR)/*dylib $(APP_BUNDLE_MACOS)
		@chmod +x $(APP_BUNDLE_MACOS)/$(APP_NAME)
		@touch $(APP_BUNDLE)
endif
		# DONE!
endif #APP_NAME

dirs: $(DIRS)
		@for d in $(DIRS); do (echo "# Entering directory $$d"; cd $$d; $(MAKE) build ); done

%.o: %.swift
		#   building $(shell echo "$*.swift")
		@$(SWIFT) $(CFLAGS) $(IMPORTS) -primary-file $*.swift \
			$(filter-out $*.swift,$(SOURCES)) -sdk $(SDK_PATH) \
			-module-name $(MODULE_NAME) -o $*.o -emit-module \
			-emit-module-path $*~partial.swiftmodule

main.o: main.swift
		# building main.swift
		@$(SWIFT) $(CFLAGS) $(IMPORTS) -emit-object -o main.o -sdk $(SDK_PATH) main.swift

clean:
		$(shell rm -fr  _obj $(OBJS) $(SWIFTMODULES) lib$(MODULE_NAME).dylib*)
ifdef DIRS
		@for d in $(DIRS); do (echo "# cleaning $$d"; cd $$d; $(MAKE) clean ); done
endif
