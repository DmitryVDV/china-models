#!/bin/zsh
# Настройка подписок Kimi Code и GLM Coding Plan на macOS.
set -euo pipefail
umask 077

provider="${1:-}"
case "$provider" in
  kimi|glm) ;;
  *) print -u2 'Запуск: zsh setup.sh kimi или zsh setup.sh glm'; exit 1 ;;
esac
if [[ "$(uname -s)" != Darwin ]]; then
  print -u2 'Этот установщик предназначен для macOS.'
  exit 1
fi
/usr/bin/perl -MJSON::PP -e '1' || {
  print -u2 'Не удалось запустить системный JSON::PP. Установка остановлена.'
  exit 1
}

export PATH="$HOME/.local/bin:$PATH"
if ! command -v claude >/dev/null 2>&1; then
  print 'Устанавливаем Claude Code…'
  curl -fsSL https://claude.ai/install.sh | bash
fi
if ! command -v claude >/dev/null 2>&1; then
  print -u2 'Claude Code не найден после установки. Открой новую вкладку и повтори команду.'
  exit 1
fi

if [[ "$provider" == kimi ]]; then
  print 'Подписка Kimi Code. Адрес подключения: https://api.kimi.ai/coding/'
  print 'Ключ: https://www.kimi.ai/code/console'
  print '1 — K3.1 Pro 256K: Plus и выше, обычная работа'
  print '2 — K3.1 Pro 1M: Pro и выше, большой проект'
  print '3 — K3.1 Pro HighSpeed 1M: Pro и выше, быстрый вывод, расход квоты ×2'
  print '4 — K3 256K: Plus и выше, прошлое поколение'
  print '5 — K3 1M: Pro и выше, прошлое поколение'
  print '6 — K2.8 Preview 1M: Plus и выше'
  print '7 — K2.7 HighSpeed 256K: Pro и выше, быстрый вывод, расход квоты ×3'
  read -r 'choice?Выбери модель [1–7, Enter = 1]: '
  case "${choice:-1}" in
    1) model='k3.1-pro'; context=262144; effort=max ;;
    2) model='k3.1-pro[1m]'; context=1048576; effort=max ;;
    3) model='k3.1-pro-highspeed[1m]'; context=1048576; effort=max ;;
    4) model='k3-256k'; context=262144; effort=high ;;
    5) model='k3[1m]'; context=1048576; effort=high ;;
    6) model='kimi-for-coding'; context=1048576; effort=high ;;
    7) model='kimi-for-coding-highspeed'; context=262144; effort=high ;;
    *) print -u2 'Нужен номер от 1 до 7. Повтори команду настройки.'; exit 1 ;;
  esac
else
  print 'Подписка GLM Coding Plan. Ключ: https://z.ai/manage-apikey/apikey-list'
  print '1 — GLM-5.3: сложная логика и разработка'
  print '2 — GLM-5.3-Flash: повседневная работа и скриншоты'
  read -r 'choice?Выбери модель [1–2, Enter = 1]: '
  case "${choice:-1}" in
    1) model='glm-5.3[1m]' ;;
    2) model='glm-5.3-flash[1m]' ;;
    *) print -u2 'Нужен номер 1 или 2. Повтори команду настройки.'; exit 1 ;;
  esac
  context=1000000
  effort=max
fi

print 'Вставь ключ. Символы на экране не появятся — это нормально.'
print 'При повторной настройке Enter сохраняет ранее введённый ключ.'
read -rs 'key?Ключ подключения: '
print

CHINA_MODELS_PROVIDER="$provider" \
CHINA_MODELS_MODEL="$model" \
CHINA_MODELS_CONTEXT="$context" \
CHINA_MODELS_EFFORT="$effort" \
CHINA_MODELS_KEY="$key" \
/usr/bin/perl -MJSON::PP -MFile::Path=make_path -MFile::Copy=copy - <<'PERL'
use strict;
use warnings;
use Fcntl qw(O_WRONLY O_CREAT O_EXCL);

my $home = $ENV{HOME};
my $provider = $ENV{CHINA_MODELS_PROVIDER};
my $model = $ENV{CHINA_MODELS_MODEL};
my $context = $ENV{CHINA_MODELS_CONTEXT};
my $dir = "$home/.config/china-models";
my $file = "$dir/$provider.json";
my $onboarding = "$home/.claude.json";
my $shell = "$home/.zshrc";

sub read_object {
    my ($path) = @_;
    return {} unless -e $path;
    open my $handle, '<', $path or die "Не удалось прочитать $path\n";
    local $/;
    my $data = eval { decode_json(<$handle>) };
    close $handle;
    die "В $path некорректный JSON. Файл не изменён.\n" if $@ || ref($data) ne 'HASH';
    return $data;
}

sub backup {
    my ($path) = @_;
    return unless -e $path;
    my $backup = "$path.china-models-backup-" . time . "-$$";
    copy($path, $backup) or die "Не удалось создать резервную копию $path\n";
    chmod 0600, $backup or die "Не удалось защитить резервную копию\n";
}

sub write_atomic {
    my ($path, $content, $mode) = @_;
    # Сохраняем цель существующей символьной ссылки.
    if (-l $path) {
        require Cwd;
        $path = Cwd::abs_path($path) // die "Повреждена ссылка $path\n";
    }
    my $temp = "$path.china-models-tmp-$$";
    sysopen my $handle, $temp, O_WRONLY | O_CREAT | O_EXCL, 0600
        or die "Не удалось создать $temp\n";
    print {$handle} $content or die "Не удалось записать $temp\n";
    close $handle or die "Не удалось сохранить $temp\n";
    chmod $mode, $temp or die "Не удалось установить права $temp\n";
    rename $temp, $path or die "Не удалось сохранить $path\n";
}

# Проверяем существующие данные до их изменения.
my $saved = read_object($file);
my $state = read_object($onboarding);
my $needs_onboarding = !$state->{hasCompletedOnboarding};
my $key = $ENV{CHINA_MODELS_KEY};
if (!length $key) {
    $key = ref($saved->{env}) eq 'HASH' ? ($saved->{env}->{ANTHROPIC_AUTH_TOKEN} // '') : '';
}
die "Ключ не введён. Повтори команду настройки.\n" unless length $key;
die "В ключе есть пробелы или переносы строк. Скопируй ключ заново.\n" if $key =~ /\s/;

my $shell_text = '';
if (-e $shell) {
    open my $handle, '<', $shell or die "Не удалось прочитать $shell\n";
    local $/;
    $shell_text = <$handle> // '';
    close $handle;
}

my %env = (
    ANTHROPIC_BASE_URL => $provider eq 'kimi' ? 'https://api.kimi.ai/coding/' : 'https://api.z.ai/api/anthropic',
    ANTHROPIC_AUTH_TOKEN => $key,
    ANTHROPIC_API_KEY => '',
    CLAUDE_CODE_OAUTH_TOKEN => '',
    ANTHROPIC_SMALL_FAST_MODEL => '',
    CLAUDE_CODE_USE_BEDROCK => '0',
    CLAUDE_CODE_USE_VERTEX => '0',
    CLAUDE_CODE_USE_FOUNDRY => '0',
    ANTHROPIC_MODEL => $model,
    CLAUDE_CODE_SUBAGENT_MODEL => $model,
    CLAUDE_CODE_AUTO_COMPACT_WINDOW => $context,
    CLAUDE_CODE_MAX_CONTEXT_TOKENS => $context,
    CLAUDE_CODE_EFFORT_LEVEL => $ENV{CHINA_MODELS_EFFORT},
);
$env{"ANTHROPIC_DEFAULT_${_}_MODEL"} = $model for qw(FABLE OPUS SONNET HAIKU);
if ($provider eq 'glm') {
    $env{ANTHROPIC_DEFAULT_HAIKU_MODEL} = 'glm-5.3-flash[1m]';
    $env{CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC} = '1';
    $env{API_TIMEOUT_MS} = '3000000';
}
my $json = JSON::PP->new->canonical->pretty;
my $profile = $json->encode({env => \%env});
$state->{hasCompletedOnboarding} = JSON::PP::true;
my $state_text = $json->encode($state);

my $launcher = <<'ZSH';
#!/bin/zsh
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
case "${0:t}" in
  claude-kimi) profile="$HOME/.config/china-models/kimi.json" ;;
  claude-glm) profile="$HOME/.config/china-models/glm.json" ;;
  *) print -u2 'Неизвестная команда запуска.'; exit 1 ;;
esac
[[ -f "$profile" ]] || { print -u2 'Повтори настройку через setup.sh.'; exit 1; }
unset CLAUDE_CONFIG_DIR ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN
unset ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL CLAUDE_CODE_SUBAGENT_MODEL
unset ANTHROPIC_DEFAULT_FABLE_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL
unset ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
unset ANTHROPIC_DEFAULT_FABLE_MODEL_NAME ANTHROPIC_DEFAULT_OPUS_MODEL_NAME
unset ANTHROPIC_DEFAULT_SONNET_MODEL_NAME ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME
unset CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY
unset CLAUDE_CODE_AUTO_COMPACT_WINDOW CLAUDE_CODE_MAX_CONTEXT_TOKENS CLAUDE_CODE_EFFORT_LEVEL
exec claude --settings "$profile" "$@"
ZSH

make_path($dir, {mode => 0700});
chmod 0700, $dir or die "Не удалось защитить папку настроек\n";
make_path("$home/.local/bin", {mode => 0755});
backup($file);
write_atomic($file, $profile, 0600);
if ($needs_onboarding) {
    backup($onboarding);
    write_atomic($onboarding, $state_text, 0600);
}
my $command = "$home/.local/bin/claude-$provider";
backup($command);
write_atomic($command, $launcher, 0700);

my $marker = '# china-models: команды запуска';
if (index($shell_text, $marker) < 0) {
    backup($shell);
    write_atomic($shell, $shell_text . "\n$marker\n" . 'export PATH="$HOME/.local/bin:$PATH"' . "\n", 0600);
}
PERL

unset key
print "Готово. Модель: $model"
print "Открой новую вкладку терминала и запусти: command claude-$provider"
print 'Внутри сессии введи /status, чтобы проверить подключение.'
