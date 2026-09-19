# Как перенести комплект в существующий форк

Архив можно распаковать как самостоятельный deploy-каталог. Рядом с каталогом в
архиве также лежит `env-docker-ready.patch` — это самый точный способ перенести
все изменения, включая удаление старых env-файлов.

Используйте чистую рабочую копию:

```bash
git clone https://github.com/AntonTolkushkin/env-docker.git
cd env-docker
git switch main
git pull --ff-only
```

Примените patch из распакованного архива и проверьте изменения:

```bash
git apply --index /path/to/env-docker-ready.patch
git status
git diff --cached --check
```

После этого можно сразу перейти к коммиту ниже. Альтернативный вариант —
распаковать содержимое каталога `env-docker-ready` прямо в корень клона.

При распаковке файлов в корень клона с заменой удалите
старые отслеживаемые env-файлы универсального dev-стека:

```bash
git rm --ignore-unmatch \
  .env \
  .env_mysql \
  .env_php \
  .env_postgresql \
  .env_push \
  .env_push_pub \
  .env_push_sub \
  .env_redis \
  .env_ssl
```

В Windows PowerShell:

```powershell
git rm --ignore-unmatch .env .env_mysql .env_php .env_postgresql .env_push .env_push_pub .env_push_sub .env_redis .env_ssl
```

Проверьте и закоммитьте:

```bash
git status
git diff --check
git add .
git diff --cached --stat
git commit -m "Add local and production Bitrix Docker stack"
git push origin main
```

Не запускайте `init-env` до `git rm`: созданный `.env` содержит реальные секреты
и не должен попасть в индекс. После коммита создайте локальный `.env` командой из
README; `.gitignore` уже исключает его.

Каталог `sources/` из исходного форка можно оставить без изменений. Для запуска
он не нужен, потому что Compose использует опубликованные образы, но его удаление
лучше оформить отдельным коммитом, если вы хотите уменьшить размер репозитория.
