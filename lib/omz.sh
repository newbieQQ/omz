# FORK FROM OH MY ZSH

ZSH_CACHE_DIR="$OMZ/cache"
SHORT_HOST=${HOST/.*/}
autoload -Uz add-zsh-hook
zmodload -i zsh/complist
unsetopt correct

_omz_auto_install_enabled() {
  [[ "${_OMZ_AUTO_INSTALL:-true}" == "true" ]] && [[ -o interactive ]]
}

_omz_can_retry_install() {
  local key="$1"
  local cooldown_seconds now ts_file ts

  cooldown_seconds=${_OMZ_AUTO_INSTALL_RETRY_SECONDS:-86400}
  ts_file="$OMZ/cache/.auto_install_${key}.ts"
  now=$(date +%s)

  [[ ! -f "$ts_file" ]] && return 0

  ts=$(cat "$ts_file" 2>/dev/null || true)
  [[ -z "$ts" ]] && return 0

  (( now - ts >= cooldown_seconds ))
}

_omz_mark_install_attempt() {
  local key="$1"
  mkdir -p "$OMZ/cache"
  date +%s > "$OMZ/cache/.auto_install_${key}.ts"
}

_omz_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

_omz_should_prefer_flatpak() {
  [[ "${_OMZ_PREFER_FLATPAK:-true}" == "true" ]]
}

_omz_detect_pkg_manager() {
  if _omz_should_prefer_flatpak && _omz_has_cmd flatpak; then
    echo "flatpak"
  elif _omz_has_cmd apt-get; then
    echo "apt"
  elif _omz_has_cmd dnf; then
    echo "dnf"
  elif _omz_has_cmd yum; then
    echo "yum"
  elif _omz_has_cmd pacman; then
    echo "pacman"
  elif _omz_has_cmd zypper; then
    echo "zypper"
  elif _omz_has_cmd apk; then
    echo "apk"
  elif _omz_has_cmd brew; then
    echo "brew"
  else
    echo ""
  fi
}

_omz_get_flatpak_app_id() {
  local pkg="$1"
  case "$pkg" in
    fzf)
      echo "${_OMZ_FLATPAK_APP_FZF:-io.github.junegunn.fzf}"
      ;;
    fd|fd-find)
      echo "${_OMZ_FLATPAK_APP_FD:-io.github.sharkdp.fd}"
      ;;
    lua|lua5.4)
      echo "${_OMZ_FLATPAK_APP_LUA:-org.lua.Lua}"
      ;;
    fastfetch)
      echo "${_OMZ_FLATPAK_APP_FASTFETCH:-com.github.dylanaraps.fastfetch}"
      ;;
    *)
      echo ""
      ;;
  esac
}

_omz_install_with_flatpak() {
  local pkg="$1"
  local app_id

  if ! _omz_has_cmd flatpak; then
    # try to install flatpak runtime via package manager
    _omz_install_with_pkg_manager "flatpak" || return 1
  fi
  _omz_has_cmd flatpak || return 1
  app_id="$(_omz_get_flatpak_app_id "$pkg")"
  [[ -n "$app_id" ]] || return 1

  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || return 1
  flatpak install -y --noninteractive flathub "$app_id" || return 1

  return 0
}

_omz_run_install_cmd() {
  if (( EUID == 0 )); then
    "$@"
    return $?
  fi

  if _omz_has_cmd sudo; then
    sudo "$@"
    return $?
  fi

  return 1
}

_omz_install_with_pkg_manager() {
  local pkg="$1"
  local manager
  manager=$(_omz_detect_pkg_manager)

  case "$manager" in
    flatpak)
      _omz_install_with_flatpak "$pkg" || {
        if _omz_has_cmd apt-get; then
          _omz_run_install_cmd apt-get update && _omz_run_install_cmd apt-get install -y "$pkg"
        elif _omz_has_cmd dnf; then
          _omz_run_install_cmd dnf install -y "$pkg"
        elif _omz_has_cmd yum; then
          _omz_run_install_cmd yum install -y "$pkg"
        elif _omz_has_cmd pacman; then
          _omz_run_install_cmd pacman -Sy --noconfirm "$pkg"
        elif _omz_has_cmd zypper; then
          _omz_run_install_cmd zypper --non-interactive install "$pkg"
        elif _omz_has_cmd apk; then
          _omz_run_install_cmd apk add "$pkg"
        elif _omz_has_cmd brew; then
          brew install "$pkg"
        else
          return 1
        fi
      }
      ;;
    apt)
      _omz_run_install_cmd apt-get update && _omz_run_install_cmd apt-get install -y "$pkg"
      ;;
    dnf)
      _omz_run_install_cmd dnf install -y "$pkg"
      ;;
    yum)
      _omz_run_install_cmd yum install -y "$pkg"
      ;;
    pacman)
      _omz_run_install_cmd pacman -Sy --noconfirm "$pkg"
      ;;
    zypper)
      _omz_run_install_cmd zypper --non-interactive install "$pkg"
      ;;
    apk)
      _omz_run_install_cmd apk add "$pkg"
      ;;
    brew)
      brew install "$pkg"
      ;;
    *)
      return 1
      ;;
  esac
}

_omz_install_fd() {
  _omz_has_cmd fd && return 0
  _omz_auto_install_enabled || return 1
  _omz_can_retry_install "fd" || return 1
  _omz_mark_install_attempt "fd"

  local manager pkg
  manager=$(_omz_detect_pkg_manager)
  pkg="fd"
  [[ "$manager" == "apt" ]] && pkg="fd-find"

  echo "[omz] fd not found, installing ${pkg}..."
  _omz_install_with_pkg_manager "$pkg" || return 1

  if _omz_has_cmd fd; then
    return 0
  fi

  if _omz_has_cmd fdfind; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    export PATH="$HOME/.local/bin:$PATH"
  fi

  _omz_has_cmd fd
}

_omz_install_fzf() {
  _omz_has_cmd fzf && return 0
  _omz_auto_install_enabled || return 1
  _omz_can_retry_install "fzf" || return 1
  _omz_mark_install_attempt "fzf"

  echo "[omz] fzf not found, trying package manager install..."
  _omz_install_with_pkg_manager "fzf" || true
  _omz_has_cmd fzf && return 0

  if [[ ! -d "$HOME/.fzf" ]] && _omz_has_cmd git; then
    echo "[omz] fallback: install fzf from github to ~/.fzf"
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" || return 1
    "$HOME/.fzf/install" --key-bindings --completion --no-bash --no-fish --no-update-rc || return 1
  fi

  _omz_has_cmd fzf
}

_omz_install_lua() {
  _omz_has_cmd lua && return 0
  _omz_auto_install_enabled || return 1
  _omz_can_retry_install "lua" || return 1
  _omz_mark_install_attempt "lua"

  echo "[omz] lua not found, installing..."
  _omz_install_with_pkg_manager "lua" || _omz_install_with_pkg_manager "lua5.4"
  _omz_has_cmd lua
}

_omz_install_conda() {
  _omz_has_cmd conda && return 0
  _omz_auto_install_enabled || return 1
  _omz_can_retry_install "conda" || return 1
  _omz_mark_install_attempt "conda"

  local installer target_dir tmp_file arch os_name
  target_dir="$HOME/.local/share/miniconda3"
  os_name="$(uname -s)"
  arch="$(uname -m)"

  case "$os_name" in
    Linux) os_name="Linux" ;;
    Darwin) os_name="MacOSX" ;;
    *)
      echo "[omz] unsupported OS for auto conda install: $os_name"
      return 1
      ;;
  esac

  case "$arch" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *)
      echo "[omz] unsupported CPU for auto conda install: $arch"
      return 1
      ;;
  esac

  installer="Miniconda3-latest-${os_name}-${arch}.sh"
  tmp_file="/tmp/${installer}"

  echo "[omz] conda not found, installing miniconda..."
  if _omz_has_cmd curl; then
    curl -fsSL "https://repo.anaconda.com/miniconda/${installer}" -o "$tmp_file" || return 1
  elif _omz_has_cmd wget; then
    wget -q "https://repo.anaconda.com/miniconda/${installer}" -O "$tmp_file" || return 1
  else
    echo "[omz] curl or wget is required to install conda"
    return 1
  fi

  bash "$tmp_file" -b -p "$target_dir" || return 1
  rm -f "$tmp_file"

  export PATH="$target_dir/bin:$PATH"
  _omz_has_cmd conda
}

autoload -U compaudit compinit
autoload -U compinit && compinit
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'
alias -- -='cd -'
alias 1='cd -'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'
alias md='mkdir -p'
alias rd=rmdir

function d () {
  if [[ -n $1 ]]; then
    dirs "$@"
  else
    dirs -v | head -10
  fi
}
compdef _dirs d
ls --color=tty . &>/dev/null && alias ls='ls --color=tty' || alias ls='ls -G'
alias lsa='ls -lah'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -lAh'

grep-flag-available() {
    echo | grep $1 "" >/dev/null 2>&1
}
GREP_OPTIONS=""
if grep-flag-available --color=auto; then
    GREP_OPTIONS+=" --color=auto"
fi
VCS_FOLDERS="{.bzr,CVS,.git,.hg,.svn}"

if grep-flag-available --exclude-dir=.cvs; then
    GREP_OPTIONS+=" --exclude-dir=$VCS_FOLDERS"
elif grep-flag-available --exclude=.cvs; then
    GREP_OPTIONS+=" --exclude=$VCS_FOLDERS"
fi
alias grep="grep $GREP_OPTIONS"
unset GREP_OPTIONS
unset VCS_FOLDERS
unfunction grep-flag-available
function omz_history {
  local clear list
  zparseopts -E c=clear l=list

  if [[ -n "$clear" ]]; then
    # if -c provided, clobber the history file
    echo -n >| "$HISTFILE"
    echo >&2 History file deleted. Reload the session to see its effects.
  elif [[ -n "$list" ]]; then
    # if -l provided, run as if calling `fc' directly
    builtin fc "$@"
  else
    [[ ${@[-1]-} = *[0-9]* ]] && builtin fc -l "$@" || builtin fc -l "$@" 1
  fi
}

case ${HIST_STAMPS-} in
  "mm/dd/yyyy") alias history='omz_history -f' ;;
  "dd.mm.yyyy") alias history='omz_history -E' ;;
  "yyyy-mm-dd") alias history='omz_history -i' ;;
  "") alias history='omz_history' ;;
  *) alias history="omz_history -t '$HIST_STAMPS'" ;;
esac

HISTFILE="$OMZ/cache/zshhistory"
HISTSIZE=50000
SAVEHIST=10000

setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify
setopt inc_append_history
setopt share_history

if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
  function zle-line-init() {
    echoti smkx
  }
  function zle-line-finish() {
    echoti rmkx
  }
  zle -N zle-line-init
  zle -N zle-line-finish
fi
bindkey -e                                            # Use emacs key bindings
bindkey '\ew' kill-region                             # [Esc-w] - Kill from the cursor to the mark
bindkey -s '\el' 'ls\n'                               # [Esc-l] - run command: ls
bindkey '^r' history-incremental-search-backward      # [Ctrl-r] - Search backward incrementally for a specified string. The string may begin with ^ to anchor the search to the beginning of the line.
if [[ "${terminfo[kpp]}" != "" ]]; then
  bindkey "${terminfo[kpp]}" up-line-or-history       # [PageUp] - Up a line of history
fi
if [[ "${terminfo[knp]}" != "" ]]; then
  bindkey "${terminfo[knp]}" down-line-or-history     # [PageDown] - Down a line of history
fi
if [[ "${terminfo[kcuu1]}" != "" ]]; then
  autoload -U up-line-or-beginning-search
  zle -N up-line-or-beginning-search
  bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
fi
if [[ "${terminfo[kcud1]}" != "" ]]; then
  autoload -U down-line-or-beginning-search
  zle -N down-line-or-beginning-search
  bindkey "${terminfo[kcud1]}" down-line-or-beginning-search
fi
if [[ "${terminfo[khome]}" != "" ]]; then
  bindkey "${terminfo[khome]}" beginning-of-line      # [Home] - Go to beginning of line
fi
if [[ "${terminfo[kend]}" != "" ]]; then
  bindkey "${terminfo[kend]}"  end-of-line            # [End] - Go to end of line
fi
bindkey ' ' magic-space                               # [Space] - do history expansion
bindkey '^[[1;5C' forward-word                        # [Ctrl-RightArrow] - move forward one word
bindkey '^[[1;5D' backward-word                       # [Ctrl-LeftArrow] - move backward one word
if [[ "${terminfo[kcbt]}" != "" ]]; then
  bindkey "${terminfo[kcbt]}" reverse-menu-complete   # [Shift-Tab] - move through the completion menu backwards
fi
bindkey '^?' backward-delete-char                     # [Backspace] - delete backward
if [[ "${terminfo[kdch1]}" != "" ]]; then
  bindkey "${terminfo[kdch1]}" delete-char            # [Delete] - delete forward
else
  bindkey "^[[3~" delete-char
  bindkey "^[3;5~" delete-char
  bindkey "\e[3~" delete-char
fi
autoload -U edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line
bindkey "^[m" copy-prev-shell-word
bindkey '^H' backward-kill-word

autoload -U colors && colors
setopt auto_cd
setopt multios
setopt prompt_subst

function git_prompt_info() {
  local ref
  if [[ "$(command git config --get oh-my-zsh.hide-status 2>/dev/null)" != "1" ]]; then
    ref=$(command git symbolic-ref HEAD 2> /dev/null) || \
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return 0
    echo "$ZSH_THEME_GIT_PROMPT_PREFIX${ref#refs/heads/}$(parse_git_dirty)$ZSH_THEME_GIT_PROMPT_SUFFIX"
  fi
}

function parse_git_dirty() {
  local STATUS
  local -a FLAGS
  FLAGS=('--porcelain')
  FLAGS+="--ignore-submodules=${GIT_STATUS_IGNORE_SUBMODULES:-dirty}"
  STATUS=$(command git status ${FLAGS} 2> /dev/null | tail -n1)
  if [[ -n $STATUS ]]; then
    echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
  else
    echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
  fi
}
