# Как применить готовый архив к форку

Архив содержит полный runtime-комплект и patch относительно актуального `main`
на момент сборки. Каталог `sources/` не дублируется в архиве: Compose использует
готовые образы, а существующий каталог `sources/` в форке нужно сохранить.

Старый каталог `confs/nginx/certs/example.com` содержал приватный тестовый ключ.
Его содержимое намеренно не переносится даже в patch: каталог нужно удалить
отдельной командой ниже.

## Вариант 1: распаковка поверх клона

```bash
git clone https://github.com/AntonTolkushkin/env-docker.git
cd env-docker
git switch main
git pull --ff-only
```

Распакуйте содержимое каталога `env-docker-ready` в корень репозитория с заменой
одноимённых файлов. Удалите файлы, которых больше нет в комплекте:

```bash
git rm -r --ignore-unmatch \
  README-REDIS-FIX.md \
  confs/nginx/certs/example.com \
  confs/nginx/ssl/finntrail.ru.conf \
  confs/php/fpm-local.conf \
  confs/php/project-local.ini \
  www/.gitkeep
```

Затем проверьте:

```bash
git status --short
git diff --check
git diff --stat
```

## Вариант 2: patch

Из корня чистой рабочей копии:

```bash
git apply --index /path/to/env-docker-ready.patch
git rm -r --ignore-unmatch confs/nginx/certs/example.com
git diff --cached --check
```

## Коммит

До `git add` убедитесь, что в статус не попали `.env`, сертификаты, ключи,
`www/public_html` или резервные копии.

```bash
git add .
git diff --cached --check
git diff --cached --stat
git commit -m "Fix local HTTPS and production Docker deployment"
git push origin main
```

После коммита выполните установку нужного режима по новому README.
