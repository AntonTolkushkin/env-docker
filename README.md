# Bitrix в Docker: локальная разработка и production

Production-ready конфигурация на основе
[`bitrix-tools/env-docker`](https://github.com/bitrix-tools/env-docker). Один набор
файлов запускается локально в Docker Desktop и на Ubuntu-сервере за внешним
Traefik.

## Состав

| Сервис | Образ | Назначение |
|---|---|---|
| `nginx` | `quay.io/bitrix24/nginx:1.30.4-v1-alpine` | HTTP, статика и FastCGI |
| `php` | `quay.io/bitrix24/php:8.4.25-fpm-v1-alpine` | PHP-FPM 8.4 |
| `cron` | тот же PHP-образ | агенты и cron Bitrix |
| `mysql` | `quay.io/bitrix24/percona-server:8.0.46-v1-rhel` | основная БД |
| `redis` | `redis:8.2.9-alpine` | PHP-сессии и кеш Bitrix |

PostgreSQL, Memcached, встроенные SSL/Lego и Push не запускаются: для обычного
интернет-магазина они не нужны. TLS в production завершает Traefik.

## Что требуется

- Docker Engine с Compose v2 на Linux или Docker Desktop на Windows/macOS;
- минимум 4 GB RAM для локального запуска;
- существующая внешняя Docker-сеть Traefik для production;
- свободный локальный порт `8588`.

## Быстрый локальный запуск

Поместите файлы сайта в каталог `www`. Если сайт еще не перенесен, каталог может
оставаться пустым до восстановления.

Linux/macOS/WSL:

```bash
./scripts/init-env.sh local
./scripts/local-up.sh
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\init-env.ps1 -Mode Local
powershell -ExecutionPolicy Bypass -File .\scripts\local-up.ps1
```

После запуска сайт доступен по адресу <http://127.0.0.1:8588>. Пароли создаются
автоматически и сохраняются только в `.env`, который исключен из Git.

Полезные команды:

```bash
docker compose ps
docker compose logs -f --tail=100 nginx php
docker compose exec php php -v
docker compose exec php sh
docker compose stop
docker compose down
```

`docker compose down` сохраняет данные. Команда `docker compose down -v` удаляет
БД, Redis и остальные именованные тома — применяйте ее только для намеренного
полного сброса локального окружения.

## Production за Traefik

На Ubuntu создайте каталоги сайта и резервных копий:

```bash
sudo install -d -o 979 -g 979 /srv/bitrix/www
sudo install -d -o "$USER" -g "$USER" /srv/bitrix/backups
./scripts/init-env.sh production
```

Отредактируйте `.env`:

- `TRAEFIK_HOST_RULE` — правило доменов Traefik, например
  ``Host(`finntrail.ru`) || Host(`www.finntrail.ru`)``; оставьте только реально
  существующие DNS-имена, иначе выпуск общего сертификата может завершиться ошибкой;
- `TRAEFIK_NETWORK` — имя внешней сети вашего Traefik;
- `TRAEFIK_*ENTRYPOINT` и `TRAEFIK_CERTRESOLVER` — имена из конфигурации Traefik;
- `MYSQL_INNODB_BUFFER_POOL_SIZE` — обычно 25–50% памяти хоста, если на нем также
  работают PHP, Redis и Traefik;
- `WWW_PATH` и `BACKUP_PATH` — если используются другие пути.

Проверьте сеть и запустите стек:

```bash
docker network ls
./scripts/validate.sh production
./scripts/deploy.sh
```

Nginx подключается к внешней сети Traefik, но его диагностический порт публикуется
только на `127.0.0.1:8588`. Порты MySQL, Redis и PHP на хосте не публикуются.

Проверка до переключения DNS:

```bash
curl -I -H 'Host: example.com' http://127.0.0.1:8588/
docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
```

Замените `example.com` реальным доменом.

## Подключение Bitrix к контейнерам

В настройках соединения Bitrix используйте:

| Параметр | Значение |
|---|---|
| сервер MySQL | `mysql` |
| порт MySQL | `3306` |
| имя БД | значение `MYSQL_DATABASE` |
| пользователь | значение `MYSQL_USER` |
| пароль | значение `MYSQL_PASSWORD` |
| Redis host | `redis` |
| Redis port | `6379` |
| Redis password | значение `REDIS_PASSWORD` |

PHP-сессии уже направлены в Redis, в отдельную БД `1`. Настройка кеша Bitrix в
Redis зависит от версии ядра и текущего содержимого `.settings.php`; пример для
переноса приведен в [docs/MIGRATION.md](docs/MIGRATION.md).

## Cron и агенты

Контейнер `cron` использует тот же PHP 8.4 и тот же каталог сайта, что и PHP-FPM.
Образ Bitrix каждую минуту запускает:

```text
/opt/www/bitrix/modules/main/tools/cron_events.php
```

Чтобы события не выполнялись одновременно на хитах, после переноса включите в
Bitrix выполнение агентов на cron согласно текущей конфигурации сайта.

## Резервное копирование

Создание согласованного дампа БД и архива файлов:

```bash
./scripts/backup.sh
```

Результат сохраняется в `BACKUP_PATH`. Скрипт не удаляет старые копии
автоматически. Обязательно копируйте резервные копии на другой сервер или в
объектное хранилище.

Восстановление только БД:

```bash
./scripts/restore-db.sh /path/to/mysql-YYYYMMDDTHHMMSSZ.sql.gz
```

Перед импортом скрипт запрашивает подтверждение, поскольку данные целевой БД
будут перезаписаны.

## Права на Linux

Контейнерные образы Bitrix работают с UID/GID `979:979`. После копирования сайта
можно проверить путь и изменить права интерактивным скриптом:

```bash
sudo ./scripts/fix-permissions.sh
```

Скрипт отказывается работать с пустым или слишком широким путем.

## Структура

```text
.
├── docker-compose.yml          # базовый и локальный режим
├── docker-compose.prod.yml     # Traefik и production PHP-настройки
├── .env.example
├── .env.production.example
├── confs/
│   ├── nginx/
│   ├── php84/
│   └── php/
├── docs/
│   └── MIGRATION.md
├── scripts/
├── www/                        # файлы сайта, не входят в Git
└── backups/                    # локальные копии, не входят в Git
```

## Обновление образов

Теги образов закреплены в `.env`, чтобы production не обновлялся неожиданно.
Обновляйте по одному компоненту: измените тег, выполните `docker compose pull`,
проверьте локально и только затем запускайте `scripts/deploy.sh` на сервере.

Не коммитьте `.env`, файлы сайта, дампы БД и архивы. Они уже добавлены в
`.gitignore`.
