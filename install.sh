#!/bin/bash

# ============================================
# RefStarsBot - Скрипт установки (FIXED v2.0)
# Одна команда для полной установки
# Исправлено: ошибка Permission denied
# ============================================

set -e  # Выход при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}       🌟 RefStarsBot - Установка и конфигурация        ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Главная установка
main() {
    print_header
    
    # Проверка OS
    print_info "Проверка операционной системы..."
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 не установлен"
        print_info "Установите Python3: sudo apt install python3 python3-pip python3-venv"
        exit 1
    fi
    
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_success "Python $PYTHON_VERSION найден"
    
    # Выбор типа установки
    print_info "Выберите тип установки:"
    echo "1) Локальная установка (для разработки)"
    echo "2) Серверная установка (production на VPS)"
    read -p "Выберите (1 или 2): " INSTALL_TYPE
    
    case $INSTALL_TYPE in
        1)
            install_local
            ;;
        2)
            install_server
            ;;
        *)
            print_error "Неверный выбор"
            exit 1
            ;;
    esac
}

# Локальная установка
install_local() {
    print_info "Начало локальной установки..."
    
    # Переменные
    PROJECT_DIR=$(pwd)
    VENV_DIR="$PROJECT_DIR/venv"
    
    # Проверка если venv уже существует
    if [ -d "$VENV_DIR" ]; then
        print_warning "Виртуальное окружение уже существует"
        read -p "Удалить старое и создать новое? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$VENV_DIR"
        fi
    fi
    
    # Создание виртуального окружения
    print_info "Создание виртуального окружения..."
    python3 -m venv "$VENV_DIR"
    print_success "Виртуальное окружение создано"
    
    # Активация
    source "$VENV_DIR/bin/activate"
    
    # Обновление pip
    print_info "Обновление pip..."
    pip install --upgrade pip setuptools wheel > /dev/null 2>&1
    print_success "pip обновлён"
    
    # Установка зависимостей
    print_info "Установка зависимостей (это может занять 2-3 минуты)..."
    if [ ! -f requirements.txt ]; then
        print_error "requirements.txt не найден!"
        exit 1
    fi
    pip install -r requirements.txt > /dev/null 2>&1
    print_success "Зависимости установлены"
    
    # Создание .env файла
    if [ ! -f .env ]; then
        print_info "Создание .env файла..."
        if [ -f .env.example ]; then
            cp .env.example .env
            print_success ".env файл создан из примера"
        else
            touch .env
            print_warning ".env.example не найден, создан пустой .env"
        fi
        print_warning "ВАЖНО: Заполните .env файл перед запуском!"
        print_info "nano .env"
    else
        print_warning ".env файл уже существует"
    fi
    
    # Завершение
    print_success "Локальная установка завершена! ✨"
    print_info "Для запуска выполните:"
    echo "  source venv/bin/activate"
    echo "  python main.py"
}

# Серверная установка
install_server() {
    print_info "Начало серверной установки (production)..."
    
    # Переменные
    BOT_USER="botuser"
    BOT_DIR="/home/$BOT_USER/RefStarsBot"
    VENV_DIR="$BOT_DIR/venv"
    
    # Проверка прав
    if [ "$EUID" -ne 0 ]; then
        print_error "Серверная установка требует прав администратора (sudo)"
        exit 1
    fi
    
    # Обновление системы
    print_info "Обновление системы..."
    apt-get update > /dev/null 2>&1 || true
    apt-get upgrade -y > /dev/null 2>&1 || true
    print_success "Система обновлена"
    
    # Установка зависимостей
    print_info "Установка системных пакетов..."
    apt-get install -y python3.10 python3.10-venv build-essential libpq-dev git curl wget nano > /dev/null 2>&1 || true
    print_success "Системные пакеты установлены"
    
    # Создание/проверка пользователя
    if ! id "$BOT_USER" &>/dev/null; then
        print_info "Создание пользователя $BOT_USER..."
        useradd -m -s /bin/bash "$BOT_USER"
        print_success "Пользователь $BOT_USER создан"
    else
        print_info "Пользователь $BOT_USER уже существует"
    fi
    
    # ВАЖНО: Проверка и очистка директории перед созданием
    if [ -d "$BOT_DIR" ]; then
        print_warning "Директория $BOT_DIR уже существует"
        print_info "Исправление прав доступа..."
        
        # Остановка сервиса если запущен
        systemctl stop refstarbot.service 2>/dev/null || true
        
        # Удаление повреждённого venv
        rm -rf "$BOT_DIR/venv" 2>/dev/null || true
        
        # Изменение владельца
        chown -R "$BOT_USER:$BOT_USER" "$BOT_DIR"
        chmod -R 755 "$BOT_DIR"
        print_success "Права исправлены"
    else
        print_info "Создание директории $BOT_DIR..."
        mkdir -p "$BOT_DIR"
        chown "$BOT_USER:$BOT_USER" "$BOT_DIR"
        chmod 755 "$BOT_DIR"
    fi
    
    cd "$BOT_DIR"
    
    # Клонирование репозитория (если нужно)
    if [ ! -f main.py ]; then
        print_info "Клонирование репозитория..."
        if git clone https://github.com/svod011929/RefStarsBot.git . 2>/dev/null; then
            print_success "Репозиторий клонирован"
        else
            print_warning "⚠️  Не удалось клонировать репозиторий"
            print_warning "⚠️  Загрузите файлы вручную в $BOT_DIR"
            print_warning "⚠️  Используйте SCP или SFTP"
            print_warning "⚠️  После загрузки запустите скрипт ещё раз"
            exit 1
        fi
    fi
    
    # Исправление прав на файлы
    print_info "Исправление прав доступа..."
    chown -R "$BOT_USER:$BOT_USER" "$BOT_DIR"
    chmod -R 755 "$BOT_DIR"
    print_success "Права установлены"
    
    # КРИТИЧНО: Создание виртуального окружения ОТ ПОЛЬЗОВАТЕЛЯ botuser
    print_info "Создание виртуального окружения..."
    
    if [ -d "$VENV_DIR" ]; then
        rm -rf "$VENV_DIR"
    fi
    
    # Попытка 1: Создание venv
    if ! su - "$BOT_USER" -c "cd $BOT_DIR && python3 -m venv venv" 2>&1; then
        print_error "Ошибка при создании venv через su"
        print_info "Пробую альтернативный способ..."
        
        # Попытка 2: Прямое создание
        python3 -m venv "$VENV_DIR" || {
            print_error "Ошибка создания виртуального окружения"
            exit 1
        }
        
        # Исправляем владельца
        chown -R "$BOT_USER:$BOT_USER" "$VENV_DIR"
    fi
    
    print_success "Виртуальное окружение создано"
    
    # Проверка что venv создан
    if [ ! -f "$VENV_DIR/bin/activate" ]; then
        print_error "Ошибка: виртуальное окружение не создано правильно"
        print_warning "Попробуйте вручную:"
        echo "  su - $BOT_USER"
        echo "  cd $BOT_DIR"
        echo "  rm -rf venv"
        echo "  python3 -m venv venv"
        exit 1
    fi
    
    # Установка зависимостей
    print_info "Установка зависимостей (2-3 минуты)..."
    if [ ! -f "$BOT_DIR/requirements.txt" ]; then
        print_error "requirements.txt не найден в $BOT_DIR"
        exit 1
    fi
    
    su - "$BOT_USER" -c "cd $BOT_DIR && source $VENV_DIR/bin/activate && pip install --upgrade pip setuptools wheel > /dev/null 2>&1 && pip install -r requirements.txt > /dev/null 2>&1" || {
        print_error "Ошибка установки зависимостей"
        exit 1
    }
    print_success "Зависимости установлены"
    
    # Создание .env файла
    if [ ! -f "$BOT_DIR/.env" ]; then
        print_info "Создание .env файла..."
        if [ -f "$BOT_DIR/.env.example" ]; then
            cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
            print_success ".env файл создан из примера"
        else
            touch "$BOT_DIR/.env"
            print_warning ".env.example не найден, создан пустой .env"
        fi
        chmod 600 "$BOT_DIR/.env"
        chown "$BOT_USER:$BOT_USER" "$BOT_DIR/.env"
        print_warning "ВАЖНО: Заполните $BOT_DIR/.env перед запуском!"
    else
        print_warning ".env файл уже существует"
    fi
    
    # Создание systemd сервиса
    print_info "Создание systemd сервиса..."
    cat > /etc/systemd/system/refstarbot.service <<'EOF'
[Unit]
Description=RefStarsBot Telegram Bot Service
After=network.target

[Service]
Type=simple
User=botuser
WorkingDirectory=/home/botuser/RefStarsBot
ExecStart=/home/botuser/RefStarsBot/venv/bin/python /home/botuser/RefStarsBot/main.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=refstarbot

[Install]
WantedBy=multi-user.target
EOF
    
    chmod 644 /etc/systemd/system/refstarbot.service
    systemctl daemon-reload
    print_success "Systemd сервис создан"
    
    # Финальные права
    print_info "Финальная установка прав доступа..."
    chown -R "$BOT_USER:$BOT_USER" "$BOT_DIR"
    chmod 755 "$BOT_DIR"
    chmod 755 "$BOT_DIR/main.py" 2>/dev/null || true
    print_success "Права установлены"
    
    # Завершение
    print_success "Серверная установка завершена! ✨"
    echo ""
    print_info "Следующие шаги:"
    echo ""
    echo "1️⃣  Отредактируйте .env файл с вашими токенами:"
    echo "   sudo nano $BOT_DIR/.env"
    echo ""
    echo "   Необходимые переменные:"
    echo "   - BOT_TOKEN (получите у @BotFather)"
    echo "   - FLYER_TOKEN (с https://flyerservice.io)"
    echo "   - DB_HOST, DB_USER, DB_PASSWORD (если используется БД)"
    echo ""
    echo "2️⃣  Включите автозапуск сервиса:"
    echo "   sudo systemctl enable refstarbot.service"
    echo ""
    echo "3️⃣  Запустите бота:"
    echo "   sudo systemctl start refstarbot.service"
    echo ""
    echo "4️⃣  Проверьте статус:"
    echo "   sudo systemctl status refstarbot.service"
    echo ""
    echo "5️⃣  Смотрите логи в реальном времени:"
    echo "   sudo journalctl -u refstarbot.service -f"
    echo ""
    echo "6️⃣  Должны увидеть в логах:"
    echo "   ✅ Flyer API инициализирован успешно"
    echo ""
    print_success "Готово! Заполните .env и запустите бота 🚀"
}

# Запуск
main
