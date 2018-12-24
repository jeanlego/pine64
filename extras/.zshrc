export LANG="en_us.UTF-8"
export TERM="xterm-256color"

[[ -z "${TMUX}" ]] && [ "${SSH_CONNECTION}" != "" ] && tmux new-session -A -s ${USER} 

autoload -Uz compinit promptinit

compinit
promptinit

source /usr/share/zsh-theme-powerlevel9k/powerlevel9k.zsh-theme