#!/usr/bin/env bash
# Интеграционная проверка: весь сценарий на чистой Ubuntu 24.04.
#   1. site.yml целиком: все действия и все проверки внутри плейбуков
#   2. повторно шаги установки: changed должен быть 0 (идемпотентность)
#   3. ещё раз части 2 и 3: роли и бэкапы повторяются без ошибок,
#      restore-date с явной датой берёт самую раннюю копию
#   4. запросы всех панелей дашбордов возвращают данные
#   5. память сервисов после нагрузки: хватает ли ВМ на 2 ГБ
# Шаг reboot пропускается: runner нельзя перезагрузить.
set -euo pipefail
ci=$(cd "$(dirname "$0")" && pwd)
cd "$ci/../../lab1-mongodb"

play() { ansible-playbook -i "$ci/inventory.ini" "$@"; }

echo "::group::1. site.yml"
play site.yml --skip-tags reboot -e load_seconds=30
echo "::endgroup::"

echo "::group::2. idempotence of install steps"
setup_tags=prepare,install,autostart,seed,exporter,victoriametrics,grafana,dashboard
play site.yml --tags "$setup_tags" | tee /tmp/idempotence.log
if ! grep -Eq 'changed=0 +unreachable=0 +failed=0' /tmp/idempotence.log; then
  echo "install steps are not idempotent:"
  grep -B1 '^changed:' /tmp/idempotence.log || true
  exit 1
fi
echo "::endgroup::"

echo "::group::3. parts 2 and 3 again"
play 02-roles.yml 03-backup.yml
as_root() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi; }
first=$(as_root ls -1 /var/backups/mongodb | grep '^shop-' | head -1)
play 03-backup.yml -t restore-date -e "restore_date=${first#shop-}" | tee /tmp/restore-date.log
grep -q "copy:    /var/backups/mongodb/$first\b" /tmp/restore-date.log
echo "::endgroup::"

echo "::group::4. dashboards"
python3 "$ci/check-dashboards.py" --vm http://127.0.0.1:8428 files/dashboards/*.json
echo "::endgroup::"

echo "::group::5. memory"
total=0
for unit in mongod mongodb_exporter victoriametrics grafana-server; do
  kb=$(ps -o rss= -p "$(systemctl show -p MainPID --value "$unit")")
  printf '%-18s %5d MB\n' "$unit" $((kb / 1024))
  total=$((total + kb))
done
printf '%-18s %5d MB\n' total $((total / 1024))
echo "::endgroup::"
