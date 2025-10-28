# 🚀 Remnawave Ultimate Installer

> **Самый простой способ установить Remnawave Panel и Node**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/DigneZzZ/remnawave-ultimate-installer)
[![Author](https://img.shields.io/badge/author-DigneZzZ-purple.svg)](https://github.com/DigneZzZ)

---

## ⚡ Быстрый старт - Один файл, одна команда

```bash
git clone https://github.com/DigneZzZ/remnawave-ultimate-installer.git
cd remnawave-ultimate-installer
sudo bash install.sh
```

**Вот и всё!** ✨ Никакого `make`, никакой сборки. Просто один файл.

---

## 📋 Что это?

**Remnawave Ultimate Installer** - универсальный установщик для:

- 🎯 **Panel Only** - Панель управления с PostgreSQL, Redis, Reverse Proxy
- 🔧 **Node Only** - VPN нода с Xray-core
- 🚀 **All-in-One** - Panel + Node на одном сервере
- 🎨 **Selfsteal** - Caddy для Xray Reality

---

## 🎬 Что внутри?

### Reverse Proxy на выбор:
- **NGINX** - с Unix socket, высокая производительность
- **Caddy** - автоматический SSL, проще в настройке

### Уровни безопасности:
- **Basic** - Только домен + SSL
- **Cookie Auth** - Cookie-based защита
- **Full Auth** - HTTP Basic Auth / 2FA

### SSL провайдеры:
- **Let's Encrypt** - Бесплатный, автоматический
- **Cloudflare DNS** - Для wildcard сертификатов
- **Self-signed** - Для тестирования

### Выбор версии Docker образов:
- **Latest** - Стабильная версия
- **Dev** - Разработческая версия

---

## 📦 Что устанавливается автоматически?

После установки вы получаете управляющие скрипты:

```bash
# Управление Panel
sudo remnawave status    # Статус сервисов
sudo remnawave logs      # Логи панели
sudo remnawave restart   # Перезапуск
sudo remnawave backup    # Создать backup
sudo remnawave restore   # Восстановить backup

# Управление Node
sudo remnanode status    # Статус ноды
sudo remnanode logs      # Логи ноды
sudo remnanode update    # Обновить ноду
sudo remnanode restart   # Перезапуск

# Управление Selfsteal
sudo selfsteal status    # Статус Caddy
sudo selfsteal logs      # Логи
sudo selfsteal templates # Управление шаблонами
```

---

## 🏗️ Архитектура 

```
┌─────────────────────────────────────────────────────────┐
│  Internet → Domain (example.com)                        │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│  Reverse Proxy (Caddy/NGINX)                            │
│  - network_mode: host                                   │
│  - SSL termination                                      │
│  - Access to localhost:3000                             │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│  Panel + PostgreSQL + Redis                             │
│  - network: bridge (remnawave-network)                  │
│  - Panel expose: 127.0.0.1:3000:3000                    │
│  - Internal communication: postgres:5432, redis:6379    │
└─────────────────────────────────────────────────────────┘
```

**Ключевые особенности:**
- ✅ Reverse proxy на **host network** (как у xxphantom)
- ✅ Backend на **localhost** (127.0.0.1:3000)
- ✅ База данных изолирована в **bridge network**
- ✅ Никаких внешних Docker networks

---

## 📚 Документация

- **[QUICK_START_NEW.md](QUICK_START_NEW.md)** - Подробный Quick Start с примерами
- **[DEVELOPMENT_PROMPT.md](DEVELOPMENT_PROMPT.md)** - Архитектура и структура проекта
- **[PROJECT_STATUS.md](PROJECT_STATUS.md)** - Статус реализации модулей


---

## 🛠️ Как это работает?

### install.sh - главный файл

1. **Проверяет root права**
2. **Загружает все модули** из `src/` в правильном порядке:
   ```
   config.sh → core/* → lib/* → providers/* → modules/* → main.sh
   ```
3. **Запускает интерактивное меню**

### Модульная структура

```
src/
├── config.sh              # Глобальная конфигурация
├── main.sh                # Главное меню
├── core/                  # Ядро системы
│   ├── colors.sh          # Цвета (70+ констант)
│   ├── display.sh         # UI функции (30+ функций)
│   └── validation.sh      # Валидация (25+ функций)
├── lib/                   # Утилиты
│   ├── crypto.sh          # Генерация ключей (30+ функций)
│   ├── http.sh            # HTTP клиент
│   ├── input.sh           # Интерактивный ввод
│   └── backup.sh          # Backup/Restore
├── providers/             # Reverse proxy
│   ├── caddy/             # Caddy provider
│   └── nginx/             # NGINX provider
└── modules/               # Модули установки
    ├── panel/             # Panel установка
    ├── node/              # Node установка
    └── all-in-one/        # Комбинированная установка
```

**Итого: ~7,800 строк кода**

---

## ❓ FAQ

### Зачем был нужен Makefile?

**Больше не нужен!** Раньше Makefile склеивал все модули в один файл. Теперь `install.sh` просто загружает модули через `source`. Проще и понятнее.

### Можно без git clone?

Пока нужен git clone. Скоро добавим:

```bash
# Coming soon
curl -sSL https://install.remnawave.com | sudo bash
```

### Какие требования к системе?

Минимум:
- **OS:** Ubuntu 20.04+, Debian 11+, CentOS 8+
- **RAM:** 1GB (рекомендуется 2GB)
- **Disk:** 5GB свободного места
- **Software:** bash, curl (устанавливается автоматически если нет)

Docker устанавливается автоматически если отсутствует.

### Поддерживает ли IPv6?

Да, автоопределение IPv4/IPv6. Приоритет IPv4.

### Можно использовать без домена?

Для тестирования - да (self-signed сертификат). Для production - нужен домен.

---

## 🎯 Примеры использования

### Простая установка Panel

```bash
sudo bash install.sh
# 1. Выбрать "Panel Only"
# 2. Ввести домен: panel.example.com
# 3. Выбрать Caddy (проще для начинающих)
# 4. Выбрать Latest версию
# 5. Дождаться окончания установки
```

### All-in-One установка

```bash
sudo bash install.sh
# 1. Выбрать "All-in-One"
# 2. Ввести домен
# 3. Выбрать NGINX (производительнее)
# 4. Выбрать Dev версию (если нужно тестировать)
# 5. Включить Xray-core
```

### Только Node

```bash
sudo bash install.sh
# 1. Выбрать "Node Only"
# 2. Ввести IP панели
# 3. Вставить SSL сертификат из Panel
# 4. Выбрать Latest версию
# 5. Включить Xray-core
```

---

## 🤝 Вклад в проект

Проект открыт для вклада! См. [DEVELOPMENT_PROMPT.md](DEVELOPMENT_PROMPT.md) для деталей архитектуры.

---

## 📞 Поддержка

- **Issues:** [GitHub Issues](https://github.com/DigneZzZ/remnawave-ultimate-installer/issues)
- **Telegram:** [@DigneZzZ](https://t.me/DigneZzZ)

---

## 📜 Лицензия

MIT License - см. [LICENSE](LICENSE)

---

## 🙏 Благодарности

Проект использует лучшие практики и идеи из:
- **remnawave-installer-main** (xxphantom) - host network архитектура
- **remnawave-reverse-proxy-main** (eGames) - NGINX конфигурации

**Автор:** [DigneZzZ](https://github.com/DigneZzZ)  
**Версия:** 1.0.0

---

<div align="center">

**Made with ❤️ for Remnawave Community**

[⬆ Вернуться наверх](#-remnawave-ultimate-installer)

</div>
