# Bitrix в Docker: local и production

Готовое окружение Bitrix на PHP 8.4, Percona Server 8.0, Redis и Nginx.
Один репозиторий поддерживает два изолированных режима:

| Режим | Домен | HTTPS | Запуск |
|---|---|---|---|
| Local | `https://finntrail.local` | локальный доверенный сертификат `mkcert` | `./scripts/local-up.sh` |
| Production | `https://finntrail.ru` | сертификат получает внешний Traefik | `./scripts/deploy.sh` |

Обычный `docker compose up` использует `docker-compose.override.yml` и поэтому
всегда означает local. Production запускается только через
`docker-compose.prod.yml`; готовые скрипты выбирают нужные файлы по `APP_ENV`.

## Состав

| Сервис | Образ | Назначение |
|---|---|---|
| `nginx` | `quay.io/bitrix24/nginx:1.30.4-v1-alpine` | HTTPS/HTTP, статика, FastCGI |
| `php` | `quay.io/bitrix24/php:8.4.25-fpm-v1-alpine` | PHP-FPM 8.4 |
| `cron` | тот же PHP-образ | cron-события Bitrix каждую минуту |
| `mysql` | `quay.io/bitrix24/percona-server:8.0.46-v1-rhel` | основная БД |
| `redis` | `redis:8.2.9-alpine` | PHP-сессии и кеш |

DocumentRoot внутри контейнеров — `/opt/www/public_html`, на хосте —
`www/public_html` для local и `/srv/bitrix/www/public_html` по умолчанию для
production.

---

# Local

## Требования

- Docker Desktop либо Docker Engine с Docker Compose `2.24.4+`;
- свободные локальные порты `80` и `443`;
- минимум 4 GB RAM;
- для macOS — Homebrew, если `mkcert` ещё не установлен.

Локальные порты публикуются только на `127.0.0.1`, поэтому сайт не открывается
другим устройствам сети.

## Быстрая установка в WSL

Из каталога репозитория:

```bash
./scripts/init-env.sh local
./scripts/local-up.sh
```

Во время `init-env.sh` откроется запрос UAC Windows. Скрипт автоматически:

1. скачает официальный `mkcert`, если он отсутствует;
2. установит локальный CA в доверенное хранилище Windows;
3. создаст сертификат для `finntrail.local`, `localhost`, `127.0.0.1` и `::1`;
4. добавит `127.0.0.1 finntrail.local` в Windows `hosts`;
5. сохранит сертификат в `confs/nginx/certs/finntrail.local`.

После запуска откройте <https://finntrail.local>.

## Быстрая установка в Windows PowerShell

Откройте PowerShell в каталоге проекта:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\init-env.ps1 -Mode Local
powershell -ExecutionPolicy Bypass -File .\scripts\local-up.ps1
```

Скрипт сертификата сам запросит права администратора. Chocolatey не требуется:
при необходимости `mkcert.exe` скачивается в
`%LOCALAPPDATA%\Programs\mkcert`.

## Быстрая установка в macOS

```bash
./scripts/init-env.sh local
./scripts/local-up.sh
```

Если `mkcert` отсутствует, скрипт установит его через Homebrew, добавит локальный
CA в Keychain и добавит `finntrail.local` в `/etc/hosts`. macOS может запросить
пароль пользователя.

## Сертификаты local отдельно

При существующем `.env` повторно запускать `init-env` не нужно. Для создания или
обновления сертификата используйте:

WSL, macOS или Linux:

```bash
./scripts/setup-local-cert.sh
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-local-cert.ps1
```

После перевыпуска сертификата пересоздайте Nginx и полностью перезапустите
браузер:

```bash
./scripts/compose.sh up -d --force-recreate nginx
```

Сертификат и его ключ исключены из Git. Никогда не копируйте и не публикуйте
`rootCA-key.pem`, создаваемый `mkcert` в профиле пользователя.

Чтобы создать `.env` без установки сертификата:

```bash
SKIP_LOCAL_CERT=1 ./scripts/init-env.sh local
```

В PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\init-env.ps1 -Mode Local -SkipLocalCertificate
```

## Файлы сайта

Поместите сайт в:

```text
www/public_html/
├── bitrix/
├── local/
├── upload/
└── index.php
```

Если файлов ещё нет, Nginx всё равно запустится и пройдёт healthcheck; страница
сайта начнёт открываться после размещения `index.php` или `index.html`.

## Управление local

```bash
./scripts/compose.sh ps
./scripts/compose.sh logs -f --tail=100 nginx php
./scripts/compose.sh exec php php -v
./scripts/compose.sh exec php sh
./scripts/compose.sh stop
./scripts/compose.sh down
```

`down` сохраняет данные. Команда `down -v` удаляет MySQL, Redis и остальные
именованные volumes — используйте её только для намеренного полного сброса.

Проверка HTTPS и healthcheck из WSL:

```bash
curl -i -H 'Host: finntrail.local' http://127.0.0.1/docker-health
curl -kI --resolve finntrail.local:443:127.0.0.1 https://finntrail.local/
```

Первый запрос должен вернуть `200 OK`, второй — ответ сайта по HTTPS.

---

# Production

Production рассчитан на Ubuntu-сервер с уже работающим Traefik. Traefik:

- слушает публичные порты `80/443`;
- перенаправляет HTTP на HTTPS;
- получает сертификат Let's Encrypt для `finntrail.ru`;
- передаёт запросы контейнеру Nginx на внутренний порт `80`.

Сам Nginx дополнительно публикуется только на `127.0.0.1:8588` для диагностики.

## 1. Подготовка каталогов

```bash
sudo install -d -o 979 -g 979 /srv/bitrix/www/public_html
sudo install -d -o "$USER" -g "$USER" /srv/bitrix/backups
```

Файлы сайта должны находиться в `/srv/bitrix/www/public_html`.

## 2. Создание production `.env`

```bash
./scripts/init-env.sh production
```

Откройте `.env` и обязательно проверьте:

```dotenv
APP_ENV=production
COMPOSE_PROJECT_NAME=bitrix-prod
WWW_PATH=/srv/bitrix/www
BACKUP_PATH=/srv/bitrix/backups
TRAEFIK_HOST_RULE='Host(`finntrail.ru`) || Host(`www.finntrail.ru`)'
TRAEFIK_NETWORK=proxy
TRAEFIK_CERTRESOLVER=letsencrypt
```

Также настройте `MYSQL_INNODB_BUFFER_POOL_SIZE` под объём памяти сервера.

## 3. Внешняя сеть Traefik

Проверьте существующую сеть:

```bash
docker network inspect proxy
```

Если имя другое, укажите его в `TRAEFIK_NETWORK`. Создавайте сеть только если
она действительно отсутствует и ваш Traefik использует это же имя:

```bash
docker network create proxy
```

## 4. Проверка и запуск

```bash
./scripts/validate.sh production
./scripts/deploy.sh
```

`deploy.sh` проверяет PHP-FPM и Nginx до обновления работающих контейнеров.

Проверка backend без переключения DNS:

```bash
curl -i -H 'Host: finntrail.ru' http://127.0.0.1:8588/docker-health
curl -I -H 'Host: finntrail.ru' http://127.0.0.1:8588/
./scripts/compose.sh ps
```

Production не использует локальные сертификаты из
`confs/nginx/certs`: сертификат и его продление полностью контролирует Traefik.

## 5. Обновление production

```bash
git pull --ff-only
./scripts/deploy.sh
```

Теги образов закреплены в `.env`. Меняйте их осознанно, сначала проверяйте
обновление локально и только затем разворачивайте в production.

---

# Общие настройки

## Подключение Bitrix

| Параметр | Значение |
|---|---|
| сервер MySQL | `mysql` |
| порт MySQL | `3306` |
| база | значение `MYSQL_DATABASE` |
| пользователь | значение `MYSQL_USER` |
| пароль | значение `MYSQL_PASSWORD` |
| Redis host | `redis` |
| Redis port | `6379` |
| Redis password | значение `REDIS_PASSWORD` |

PHP-сессии используют Redis database `1`, кешу Bitrix можно назначить database
`0`. Пример переноса приведён в [docs/MIGRATION.md](docs/MIGRATION.md).

## Cron

Контейнер `cron` каждую минуту проверяет и запускает:

```text
/opt/www/public_html/bitrix/modules/main/tools/cron_events.php
```

Скрипт пропускает запуск во время установки Bitrix. Чтобы события не выполнялись
одновременно на хитах, настройте агенты Bitrix на cron в самом проекте.

## Резервное копирование

```bash
./scripts/backup.sh
```

Создаются согласованный дамп MySQL и архив каталога `WWW_PATH`. Кеши Bitrix и
`upload/tmp` в архив файлов не включаются.

Восстановление БД:

```bash
./scripts/restore-db.sh /path/to/mysql-YYYYMMDDTHHMMSSZ.sql.gz
```

## Права на production

Образы Bitrix используют UID/GID `979:979`:

```bash
sudo ./scripts/fix-permissions.sh
```

Скрипт показывает целевой каталог и запрашивает подтверждение перед рекурсивным
изменением прав.

## Структура

```text
.
├── docker-compose.yml             # общие сервисы и исправления
├── docker-compose.override.yml    # local: finntrail.local, 80/443
├── docker-compose.prod.yml        # production: finntrail.ru + Traefik
├── .env.example
├── .env.production.example
├── confs/
│   ├── cron/
│   ├── nginx/
│   ├── php84/
│   └── php/
├── docs/
├── scripts/
├── www/public_html/               # local DocumentRoot, исключён из Git
└── backups/                       # резервные копии, исключены из Git
```

Не коммитьте `.env`, сертификаты, приватные ключи, файлы сайта, дампы или архивы.
