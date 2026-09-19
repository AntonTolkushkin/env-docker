# Исправление запуска Redis

Этот overlay исправляет ошибку:

```text
Can't open or create append-only dir appendonlydir: Permission denied
```

## Применение

1. Скопируйте `docker-compose.override.yml` в корень проекта — рядом с
   `docker-compose.yml` и `.env`.
2. Выполните:

   ```bash
   docker compose config --quiet
   docker compose up -d --force-recreate redis
   docker compose up -d
   docker compose ps
   docker compose logs --tail=50 redis
   ```

Удалять Docker volumes не нужно: база MySQL и данные Redis сохранятся.

После проверки добавьте `docker-compose.override.yml` в Git. Docker Compose
подхватывает этот файл автоматически и заменяет только ошибочную команду
сервиса `redis`.
