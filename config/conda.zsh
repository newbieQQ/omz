# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if command -v conda >/dev/null 2>&1; then
    __conda_setup="$(conda shell.zsh hook 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        _OMZ_CONDA_BIN_DIR="$(cd "$(dirname "$(command -v conda)")" && pwd)"
        if [ -f "${_OMZ_CONDA_BIN_DIR}/../etc/profile.d/conda.sh" ]; then
            . "${_OMZ_CONDA_BIN_DIR}/../etc/profile.d/conda.sh"
        else
            export PATH="${_OMZ_CONDA_BIN_DIR}:$PATH"
        fi
        unset _OMZ_CONDA_BIN_DIR
    fi
    unset __conda_setup
fi

if command -v conda >/dev/null 2>&1; then
    _OMZ_CONDA_EXE="${CONDA_EXE:-$(whence -p conda 2>/dev/null)}"
    if [ -x "$_OMZ_CONDA_EXE" ]; then
        _OMZ_CONDA_ROOT="$(cd "$(dirname "$_OMZ_CONDA_EXE")/.." && pwd)"
        _OMZ_CONDA_COMP_DIR="${_OMZ_CONDA_ROOT}/share/zsh/site-functions"

        if [ -d "$_OMZ_CONDA_COMP_DIR" ] && [ -f "$_OMZ_CONDA_COMP_DIR/_conda" ]; then
            (( ${fpath[(I)$_OMZ_CONDA_COMP_DIR]} == 0 )) && fpath=("$_OMZ_CONDA_COMP_DIR" $fpath)
            autoload -Uz _conda
            compdef _conda conda
        fi

        unset _OMZ_CONDA_ROOT
        unset _OMZ_CONDA_COMP_DIR
    fi
    unset _OMZ_CONDA_EXE
fi
# <<< conda initialize <<<

alias ca="conda activate"
compdef ca=conda 2>/dev/null || true


