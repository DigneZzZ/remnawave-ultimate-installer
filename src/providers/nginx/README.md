# NGINX Provider для Remnawave Ultimate Installer

## Описание

NGINX provider предоставляет полную интеграцию с NGINX для Remnawave Ultimate Installer. Поддерживает три уровня безопасности и автоматическую настройку SSL сертификатов.

## Структура

```
src/providers/nginx/
├── install.sh          # Установка и управление NGINX
├── config.sh           # Генерация конфигураций
├── ssl.sh             # Управление SSL сертификатами
└── templates/
    ├── basic.conf         # Базовая конфигурация
    ├── cookie-auth.conf   # Cookie Auth с selfsteal
    └── full-auth.conf     # HTTP Basic Auth
```

## Возможности

### 1. Установка и управление (`install.sh`)

- **install_nginx()** - Полная установка NGINX в Docker контейнере
- **start/stop/restart_nginx()** - Управление контейнером
- **reload_nginx()** - Перезагрузка конфигурации без даунтайма
- **status_nginx()** - Проверка статуса
- **logs_nginx()** - Просмотр логов
- **validate_nginx_conf()** - Проверка конфигурации перед применением
- **uninstall_nginx()** - Удаление с резервным копированием

### 2. Генерация конфигураций (`config.sh`)

#### Основные функции

- **generate_nginx_main_conf()** - Основной nginx.conf с оптимизациями
- **generate_nginx_conf_basic()** - Простая конфигурация (только домен)
- **generate_nginx_conf_cookie_auth()** - Cookie Auth с selfsteal интеграцией
- **generate_nginx_conf_full_auth()** - HTTP Basic Authentication

#### Управление доменами

- **add_domain_to_nginx()** - Добавление нового домена
- **remove_domain_from_nginx()** - Удаление домена
- **add_upstream_to_nginx()** - Добавление upstream сервера
- **remove_upstream_from_nginx()** - Удаление upstream

#### Резервное копирование

- **backup_nginx_config()** - Создание резервной копии
- **restore_nginx_config()** - Восстановление из бэкапа

### 3. SSL сертификаты (`ssl.sh`)

#### Let's Encrypt

- **install_certbot()** - Установка Certbot
- **obtain_letsencrypt_standalone()** - Получение сертификата (standalone)
- **obtain_letsencrypt_webroot()** - Получение сертификата (webroot)
- **renew_letsencrypt_certificates()** - Обновление сертификатов

#### Cloudflare DNS

- **install_certbot_cloudflare()** - Установка Cloudflare plugin
- **obtain_cloudflare_certificate()** - Получение wildcard сертификата

#### Self-Signed

- **generate_self_signed_certificate()** - Создание self-signed сертификата
- **generate_self_signed_san_certificate()** - С Subject Alternative Names

#### Проверка и управление

- **validate_ssl_certificate()** - Проверка валидности сертификата
- **get_certificate_info()** - Подробная информация о сертификате
- **check_all_certificates_expiry()** - Проверка всех сертификатов на истечение
- **setup_certificate_auto_renewal()** - Настройка автоматического обновления

## Уровни безопасности

### Basic (Базовый)

Простая конфигурация с автоматическим редиректом HTTP → HTTPS.

```bash
generate_nginx_conf_basic "example.com" "http://remnawave-panel:3000"
```

**Особенности:**
- Автоматический редирект на HTTPS
- WebSocket support
- Security headers
- Health check endpoint

### Cookie Auth

Cookie-based аутентификация через selfsteal.

```bash
generate_nginx_conf_cookie_auth "example.com" "http://remnawave-panel:3000" \
    "http://selfsteal:8080" "secret123"
```

**Особенности:**
- Cookie validation через `map` директиву
- Интеграция с selfsteal для страницы входа
- Редирект неавторизованных пользователей на `/auth`
- Кэширование статических ресурсов

### Full Auth

HTTP Basic Authentication (логин/пароль).

```bash
generate_nginx_conf_full_auth "example.com" "http://remnawave-panel:3000" \
    "admin" "password123"
```

**Особенности:**
- HTTP Basic Auth через `.htpasswd`
- Стандартная браузерная форма входа
- Health check без авторизации

## SSL Providers

### 1. Let's Encrypt (рекомендуется)

```bash
# Standalone (требует остановку NGINX)
obtain_letsencrypt_standalone "example.com" "admin@example.com"

# Webroot (без остановки)
obtain_letsencrypt_webroot "example.com" "admin@example.com" "/var/www/html"
```

**Автоматическое обновление:**
```bash
setup_certificate_auto_renewal
```

Создаст cron задачу для ежедневной проверки и обновления сертификатов.

### 2. Cloudflare DNS

Для wildcard сертификатов:

```bash
obtain_cloudflare_certificate "example.com" "admin@example.com" "cloudflare_api_token"
```

Получит сертификаты для `example.com` и `*.example.com`.

### 3. Self-Signed

Для тестирования:

```bash
generate_self_signed_certificate "example.com" 365
```

⚠️ **Внимание:** Self-signed сертификаты вызывают предупреждения в браузерах!

## Примеры использования

### Установка NGINX с Basic Auth

```bash
# Установка NGINX
install_nginx

# Генерация main config
generate_nginx_main_conf

# Получение Let's Encrypt сертификата
obtain_letsencrypt_standalone "panel.example.com" "admin@example.com"

# Генерация конфигурации
generate_nginx_conf_basic "panel.example.com" "http://remnawave-panel:3000"

# Применение
reload_nginx
```

### Установка с Cookie Auth

```bash
# Установка NGINX
install_nginx

# Main config + SSL
generate_nginx_main_conf
obtain_letsencrypt_standalone "panel.example.com" "admin@example.com"

# Cookie Auth (с selfsteal)
generate_nginx_conf_cookie_auth \
    "panel.example.com" \
    "http://remnawave-panel:3000" \
    "http://selfsteal:8080" \
    "$(generate_random_string 32)"

reload_nginx
```

### Установка с HTTP Basic Auth

```bash
# Установка NGINX
install_nginx

# Main config + SSL
generate_nginx_main_conf
obtain_cloudflare_certificate "panel.example.com" "admin@example.com" "$CF_TOKEN"

# Full Auth
generate_nginx_conf_full_auth \
    "panel.example.com" \
    "http://remnawave-panel:3000" \
    "admin" \
    "SecurePassword123"

reload_nginx
```

## Проверка и отладка

### Проверка конфигурации

```bash
validate_nginx_conf
```

### Просмотр статуса

```bash
status_nginx
```

### Просмотр логов

```bash
# Последние 50 строк
logs_nginx 50

# Real-time monitoring
logs_nginx 100
```

### Проверка SSL сертификатов

```bash
# Информация о конкретном сертификате
get_certificate_info "example.com"

# Проверка всех сертификатов
check_all_certificates_expiry
```

## Резервное копирование

### Создание бэкапа

```bash
# Конфигурация
backup_nginx_config "before_upgrade"

# SSL сертификаты
backup_ssl_certificates "ssl_backup_before_renewal"

# Полный экспорт
export_nginx_config "/backup/nginx_full"
```

### Восстановление

```bash
# Конфигурация
restore_nginx_config "/backup/nginx_backup_20240101_120000"

# SSL сертификаты
restore_ssl_certificates "/backup/ssl_backup_20240101_120000"

# Импорт
import_nginx_config "/backup/nginx_export_20240101_120000"
```

## Docker Integration

NGINX запускается в Docker контейнере:

```yaml
services:
  nginx:
    image: nginx:alpine
    container_name: remnawave-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./nginx/logs:/var/log/nginx
    networks:
      - remnawave-network
```

## Оптимизации

### nginx.conf включает:

- **Worker processes:** auto
- **Worker connections:** 1024 с epoll
- **Gzip compression:** уровень 6
- **SSL:** TLSv1.2/1.3 с современными ciphers
- **Security headers:** X-Frame-Options, CSP, etc.
- **Keepalive:** оптимизированные таймауты
- **Client max body size:** 100MB

### Upstream оптимизации:

- **Keepalive connections:** 32 для backend, 16 для auth
- **HTTP/1.1** для WebSocket support
- **Buffering:** отключен для real-time приложений

## Отличия от Caddy

| Функция | NGINX | Caddy |
|---------|-------|-------|
| **SSL** | Ручная настройка через Certbot | Автоматическая через ACME |
| **Конфигурация** | Директивы в файлах .conf | Caddyfile DSL |
| **WebSocket** | Требует настройки headers | Автоматическая поддержка |
| **Производительность** | Выше при больших нагрузках | Хорошая для средних нагрузок |
| **Cookie Auth** | map директива | basicauth + cookie matcher |
| **Сложность** | Требует больше знаний | Проще для новичков |

## Требования

- Docker 20.10+
- Docker Compose v2+
- Bash 4.0+
- OpenSSL
- Certbot (для Let's Encrypt)
- Python3 + pip (для Cloudflare DNS)

## Troubleshooting

### NGINX не запускается

```bash
# Проверка логов
logs_nginx 100

# Проверка конфигурации
validate_nginx_conf

# Проверка портов
netstat -tulpn | grep -E ':(80|443)'
```

### SSL ошибки

```bash
# Проверка сертификата
validate_ssl_certificate "example.com"

# Информация о сертификате
get_certificate_info "example.com"

# Перевыпуск
obtain_letsencrypt_standalone "example.com" "admin@example.com"
```

### Cookie Auth не работает

1. Проверьте, что selfsteal контейнер запущен
2. Убедитесь, что cookie secret правильный
3. Проверьте настройки map директивы в конфиге

```bash
grep "map.*auth_cookie" /opt/remnawave/nginx/conf.d/*.conf
```

## Интеграция с модулями

NGINX провайдер интегрирован в:

- ✅ **panel/install.sh** - Выбор между Caddy и NGINX при установке панели
- ✅ **all-in-one/install.sh** - Поддержка NGINX в all-in-one режиме
- ✅ **Makefile** - Автоматическое включение в сборку

## Лицензия

Часть Remnawave Ultimate Installer
