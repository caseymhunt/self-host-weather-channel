# WeatherStar 4000 - Project Makefile
# Always use these make targets instead of running docker compose directly.
# This ensures messages.env is always regenerated from messages.txt before
# any docker compose command is run.

MESSAGES_FILE = messages.txt
MESSAGES_ENV  = messages.env
SETTINGS_ENV  = settings.env

include $(SETTINGS_ENV)

.PHONY: up down restart logs preview

# Generate messages.env from messages.txt
$(MESSAGES_ENV): $(MESSAGES_FILE)
	@if grep -v '^#' $(MESSAGES_FILE) | grep -q '|'; then \
		echo "WARNING: Pipe character (|) found in $(MESSAGES_FILE). This will break message formatting."; \
	fi
	@MESSAGES=$$(grep -v '^#' $(MESSAGES_FILE) | grep -v '^$$' | sed 's/[[:space:]]*$$//' | paste -sd '|' -) && \
	echo "WSQS_settings_customText_string=$$MESSAGES" > $(MESSAGES_ENV)
	@echo "Generated $(MESSAGES_ENV)"

up: $(MESSAGES_ENV)
	docker compose --env-file $(SETTINGS_ENV) up -d

down:
	docker compose --env-file $(SETTINGS_ENV) down

# Restart all containers - useful for diagnostics
restart:
	docker compose --env-file $(SETTINGS_ENV) restart

preview:
	@IP=$$(hostname -I | awk '{print $$1}') && \
	echo "Open in browser: http://$$IP:8080/"

logs:
	docker compose --env-file $(SETTINGS_ENV) logs -f
