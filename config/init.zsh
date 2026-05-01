_OMZ_INSTALL_STATE_FILE="$OMZ/cache/install.state"

_omz_read_install_state() {
    if [ -f "$_OMZ_INSTALL_STATE_FILE" ]; then
        cat "$_OMZ_INSTALL_STATE_FILE" 2>/dev/null
    fi
}

_omz_write_install_state() {
    local state="$1"
    mkdir -p "$OMZ/cache"
    echo "$state" > "$_OMZ_INSTALL_STATE_FILE"
}

_omz_run_install_steps() {
    local prev_auto_install prev_retry_seconds failed
    prev_auto_install="${_OMZ_AUTO_INSTALL:-}"
    prev_retry_seconds="${_OMZ_AUTO_INSTALL_RETRY_SECONDS:-}"
    _OMZ_AUTO_INSTALL=true
    _OMZ_AUTO_INSTALL_RETRY_SECONDS=0
    failed=0

    _omz_install_fd || failed=1
    _omz_install_fzf || failed=1
    _omz_install_lua || failed=1
    _omz_install_conda || failed=1

    if [ -n "$prev_auto_install" ]; then
        _OMZ_AUTO_INSTALL="$prev_auto_install"
    else
        unset _OMZ_AUTO_INSTALL
    fi

    if [ -n "$prev_retry_seconds" ]; then
        _OMZ_AUTO_INSTALL_RETRY_SECONDS="$prev_retry_seconds"
    else
        unset _OMZ_AUTO_INSTALL_RETRY_SECONDS
    fi

    return $failed
}

_omz_run_update_steps() {
    local prev_retry_seconds failed
    prev_retry_seconds="${_OMZ_AUTO_INSTALL_RETRY_SECONDS:-}"
    _OMZ_AUTO_INSTALL_RETRY_SECONDS=0
    failed=0

    if _omz_has_cmd fd; then
        _omz_install_with_pkg_manager "fd-find" || _omz_install_with_pkg_manager "fd" || failed=1
    else
        _omz_install_fd || failed=1
    fi

    if [ -d "$HOME/.fzf/.git" ] && _omz_has_cmd git; then
        git -C "$HOME/.fzf" pull --ff-only || failed=1
        "$HOME/.fzf/install" --key-bindings --completion --no-bash --no-fish --no-update-rc || failed=1
    elif _omz_has_cmd fzf; then
        _omz_install_with_pkg_manager "fzf" || failed=1
    else
        _omz_install_fzf || failed=1
    fi

    if _omz_has_cmd lua; then
        _omz_install_with_pkg_manager "lua" || _omz_install_with_pkg_manager "lua5.4" || failed=1
    else
        _omz_install_lua || failed=1
    fi

    if _omz_has_cmd conda; then
        conda update -n base -y conda || failed=1
    else
        _omz_install_conda || failed=1
    fi

    if [ -n "$prev_retry_seconds" ]; then
        _OMZ_AUTO_INSTALL_RETRY_SECONDS="$prev_retry_seconds"
    else
        unset _OMZ_AUTO_INSTALL_RETRY_SECONDS
    fi

    return $failed
}

omz_install() {
    local state
    state="$(_omz_read_install_state)"

    if [ "$state" = "managed" ]; then
        echo "[omz] install mode=managed, running dependency update..."
        _omz_run_update_steps || {
            echo "[omz] some dependencies failed to update"
            return 1
        }
        echo "[omz] dependency update finished"
        return 0
    fi

    echo "[omz] running first-time dependency install..."
    _omz_run_install_steps || {
        echo "[omz] some dependencies failed to install"
        return 1
    }

    _omz_write_install_state "managed"
    echo "[omz] install finished, future install will perform update"
}

inttall() {
    omz_install "$@"
}

if [[ "${_OMZ_ENABLE_INSTALL_COMMAND:-true}" == "true" ]]; then
    install() {
        if [ "$#" -eq 0 ]; then
            omz_install
        else
            command install "$@"
        fi
    }
fi

_omz_init_install_prompt() {
    local state answer
    [[ -o interactive ]] || return 0
    [[ "${_OMZ_INSTALL_PROMPT:-true}" == "true" ]] || return 0

    state="$(_omz_read_install_state)"
    if [ "$state" = "managed" ] || [ "$state" = "deferred" ]; then
        return 0
    fi

    printf "[omz] Install dependencies now (fzf/fd/lua/conda)? [y/N]: "
    read -r answer

    case "$answer" in
        y|Y|yes|YES)
            omz_install
            ;;
        *)
            _omz_write_install_state "deferred"
            echo "[omz] dependencies skipped, run 'inttall' to install later"
            ;;
    esac
}

_omz_init_install_prompt
