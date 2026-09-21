# Как применить готовый ZIP или patch к форку

Комплект собран относительно commit `962aa93` ветки `main`.

## Вариант 1: готовый ZIP

Распакуйте архив в отдельный каталог. В нём уже находится полный репозиторий
без `.git`, `.env`, сертификатов, баз, сайта и резервных копий.

Чтобы заменить содержимое существующего клона и сохранить его Git history:

```bash
cd /path/to/existing/env-docker
git status --short
rsync -a --delete \
  --exclude='.git/' \
  --exclude='.env' \
  --exclude='www/' \
  /path/to/unpacked/env-docker-ready/ ./
git status --short
git diff --check
```

Перед `rsync --delete` убедитесь, что путь архива и текущего клона указаны
правильно. Файлы сайта находятся вне production/development-клонов по
`WWW_PATH`, поэтому в архив не входят.

## Вариант 2: patch

Из чистой рабочей копии на commit `962aa93`:

```bash
git switch main
git pull --ff-only
git apply --check /path/to/env-docker-prod-dev.patch
git apply --index /path/to/env-docker-prod-dev.patch
git diff --cached --check
```

Если `main` уже изменился, сначала создайте отдельную ветку и примените patch
без `--index`, затем разрешите конфликты вручную.

## Коммит

Проверьте, что в индекс не попали `.env`, `confs/nginx/auth/dev.htpasswd`,
сертификаты, дампы или файлы сайта:

```bash
git status --short
git diff --cached --stat
git commit -m "Add isolated prod and multi-site development deployment"
git push origin main
```
