#==============================================================================
#  ~/.profile
#
#  Note: make sure this file is dash/sh compatible
#  dash ~/.profile
#==============================================================================

source /root/.colorrc

# Modify this file to reflect your specific requirements

# Global Environment Variables
export EDITOR=vim
export VISUAL=vim

export PS1="${BRed}\u@\h${NC}: ${Red}\w${NC} \\$ "

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTFILE=/root/.histfile
HISTSIZE=100000
HISTFILESIZE=$HISTSIZE
HISTCONTROL=ignorespace:ignoredups:erasedups
HISTTIMEFORMAT=""
PROMPT_COMMAND=_bash_history_sync
