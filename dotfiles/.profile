#==============================================================================
#  ~/.profile
#
#  Note: make sure this file is dash/sh compatible
#  dash ~/.profile
#==============================================================================

. ~/.colorrc

# Modify this file to reflect your specific requirements

# Global Environment Variables
export EDITOR=vim
export VISUAL=vim

export PATH="${HOME}/bin:${HOME}/.local/bin:${PATH}"

# enable Kvantum theme engine for Qt apps
export QT_QPA_PLATFORMTHEME=kvantum

export PS1="${BBlue}\u@\h: ${BCyan}\w${BPurple}\$(parseGitBranch) ${Yellow}\$(date +%H:%M:%S)\n${BCyan}\\$ ${NC}"

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTFILE=$HOME/.histfile
HISTSIZE=100000
HISTFILESIZE=$HISTSIZE
HISTCONTROL=ignorespace:ignoredups:erasedups
HISTTIMEFORMAT=""
PROMPT_COMMAND=_bash_history_sync
