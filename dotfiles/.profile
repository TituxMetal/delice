#==============================================================================
#  ~/.profile
#
#  Note: make sure this file is dash/sh compatible
#  dash ~/.profile
#==============================================================================

source ~/.colorrc

# Modify this file to reflect your specific requirements

# Global Environment Variables
export EDITOR=vim
export VISUAL=vim

export PATH="${HOME}/bin:${HOME}/.local/bin:${PATH}"

# enable qt5ct config
export QT_QPA_PLATFORMTHEME=qt5ct

# determine network interface
export NET=$(ip route get 2.2.2.2 | awk -- '{printf $5}')

export PS1="${BBlue}\u@\h: ${BCyan}\w${BPurple}\$(parseGitBranch) ${Yellow}\$(date +%H:%M:%S)\n${BCyan}\\$ ${NC}"

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTFILE=$HOME/.histfile
HISTSIZE=100000
HISTFILESIZE=$HISTSIZE
HISTCONTROL=ignorespace:ignoredups:erasedups
HISTTIMEFORMAT=""
PROMPT_COMMAND=_bash_history_sync
