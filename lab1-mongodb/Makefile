# Проверки кода. Те же команды запускает GitHub Actions (.github/workflows/lab1-mongodb.yml).
SH := files/mongo-admin files/mongo-try files/mongo-backup files/mongo-health ../.github/lab1-mongodb/*.sh

.PHONY: lint
lint:
	yamllint .
	ansible-lint
	shellcheck $(SH)
	shfmt -d -i 2 -ci $(SH)
	ruff check files/vmquery.py ../.github/lab1-mongodb/*.py
	ruff format --check files/vmquery.py ../.github/lab1-mongodb/*.py
	python3 ../.github/lab1-mongodb/check-dashboards.py files/dashboards/*.json
	# dashboard-linter только для своего дашборда: 12079 чужой, взят как есть.
	dashboard-linter lint --strict -c ../.github/lab1-mongodb/dashboard-lint.yml files/dashboards/mongodb-lab.json
