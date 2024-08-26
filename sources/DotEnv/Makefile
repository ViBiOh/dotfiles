SHELL = /usr/bin/env bash -o nounset -o pipefail -o errexit -c

ifneq ("$(wildcard $(TARGET_ENV_FILE))","")
	include $(TARGET_ENV_FILE)
	export
endif

.PHONY: env
env:
	printenv
