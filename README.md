# Kimi, GLM и Qwen: подписки и настройка

Kimi и GLM подключаем к Claude Code на Mac и Windows. Qwen Code запускаем отдельно в Терминале на Mac.

- [Kimi — установка и настройка](KIMI.md)
- [GLM — установка и настройка](GLM.md)
- [Qwen Code на Mac — интерактивный гайд](https://dmitryvdv.github.io/china-models/) — где оплатить Token Plan, взять ключ и проверить модели в `/model`.

## Подключение Kimi и GLM к Claude Code

### Вариант 1 — попросить Kimi CLI

Установи Kimi CLI, войди в подписку и вставь готовую просьбу из нужной инструкции. Kimi поможет установить Claude Code, создать настройки и проверить подключение. Команды установки приведены отдельно для Mac и Windows.

Этот способ подходит и для GLM: Kimi помогает с настройкой, затем Claude Code работает по подписке GLM. Для самой помощи нужен доступ к Kimi Code. Если подписки Kimi нет, используй вариант 2.

### Вариант 2 — готовый установщик

Скачай папку целиком: **Code → Download ZIP**, затем распакуй. Скрипты уже написаны; нужно только выбрать модель и вставить ключ подписки.

| Система | Kimi | GLM |
| --- | --- | --- |
| Mac, «Терминал» | `zsh setup.sh kimi` | `zsh setup.sh glm` |
| Windows, PowerShell | `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 kimi` | `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 glm` |

Запускай команду из папки с [setup.sh](setup.sh) или [setup.ps1](setup.ps1). Как открыть терминал в нужной папке, объяснено в обеих инструкциях.

После настройки открой новое окно терминала в папке своего проекта. На Mac запускай `command claude-kimi` или `command claude-glm`, на Windows — `claude-kimi` или `claude-glm`.

Используем включённую в подписку квоту. Ключ подключения нужен для доступа Claude Code к подписке. Для международного аккаунта Kimi адрес — **`https://api.kimi.ai/coding/`**, ключ создаётся в [Kimi Code Console на kimi.ai](https://www.kimi.ai/code/console).

## Оплата подписок

Карта зарубежного банка за 2 минуты с пополнением в рублях через СБП

[Оформить карту](https://platipomiru.com/?code=G044RB0S)
