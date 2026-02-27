CONTIKI_PROJECT = mqtt-client
all: $(CONTIKI_PROJECT)

CONTIKI ?= /home/user/contiki-ng

include $(CONTIKI)/Makefile.dir-variables
MODULES += $(CONTIKI_NG_APP_LAYER_DIR)/mqtt
include $(CONTIKI)/Makefile.identify-target

PLATFORMS_ONLY = native

include $(CONTIKI)/Makefile.include
