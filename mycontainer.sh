#!/bin/bash

# Проверяем права (нужен root для unshare и cgroups)
if [[ $EUID -ne 0 ]]; then
   echo "Error: запустите скрипт через sudo"
   exit 1
fi

# Проверяем что переданы все необходимые аргументы
if [ $# -lt 2 ]; then
    echo "Error: недостаточно аргументов"
    echo "Использование: sudo $0 <команда> <лимит_памяти>"
    echo "В случае, если необходимо запустить команду с флагами или параметрами, для корректной работы требуется запускать в кавычках. Пример: sudo $0 \"ls -lah\" 128M"
    echo "Пример: sudo $0 bash 128M"
    exit 1
fi

CMD=$1
MEMORY_LIMIT=$2

# Проверяем является ли лимит памяти числом (допускается число с буквой M или G на конце)
if [[ ! $MEMORY_LIMIT =~ ^[0-9]+[MG]?$ ]]; then
    echo "Error: лимит памяти должен быть числом (например, 128 или 128M)"
    exit 1
fi

# Уникальная контрольная группа для запуска
CGROUP_NAME="container_$$"

# Функция очистки ресурсов
cleanup() {
    rmdir "/sys/fs/cgroup/$CGROUP_NAME"
    echo "Контейнер закрыт, ресурсы освобождены"
}

# Перехват выхода
trap cleanup EXIT INT TERM

# Создаем cgroup и устанавливаем лимит
mkdir "/sys/fs/cgroup/$CGROUP_NAME"
echo "${MEMORY_LIMIT}" > "/sys/fs/cgroup/$CGROUP_NAME/memory.max"

# Запуск изолированного процесса с привязкой к cgroup
unshare --fork --pid --uts --mount --net --mount-proc bash -c "
    echo \$$ > /sys/fs/cgroup/$CGROUP_NAME/cgroup.procs
    hostname container-host
    exec $CMD
"

EXIT_CODE=$?

# Проверка кода возврата
if [ $EXIT_CODE -ne 0 ]; then
    echo "Процесс завершился с ненулевым кодом (Код ошибки: $EXIT_CODE)"
else
    echo "Процесс успешно завершен"
fi

exit $EXIT_CODE
