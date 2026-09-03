.PHONY: all setup gen watch analyze test coverage format clean check db-up db-down db-logs

# --- Mobile (Flutter) Targets ---
setup:
	cd apps/mobile && flutter pub get
	$(MAKE) gen

gen:
	cd apps/mobile && dart run build_runner build --delete-conflicting-outputs

watch:
	cd apps/mobile && dart run build_runner watch --delete-conflicting-outputs

analyze:
	cd apps/mobile && flutter analyze

test:
	cd apps/mobile && flutter test

coverage:
	cd apps/mobile && flutter test --coverage
	@echo "Reporte en apps/mobile/coverage/lcov.info"

format:
	cd apps/mobile && dart format lib test

clean:
	cd apps/mobile && flutter clean
	cd apps/mobile && flutter pub get

check: format analyze test

# --- Backend & Database Targets ---
db-up:
	docker compose up -d postgres

db-down:
	docker compose down

db-logs:
	docker compose logs -f postgres
