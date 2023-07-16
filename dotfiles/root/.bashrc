#==============================================================================
#  /root/.bashrc
#  executed by bash(1) for non-login shells.
#==============================================================================

# Modify this file to reflect your specific requirements

#------------------------------------------------------------------------------
#  Global aliases & functions #
#------------------------------------------------------------------------------

_bash_history_sync() {
  builtin history -a
  HISTFILESIZE=$HISTSIZE
  builtin history -c
  builtin history -r
}

history() {
  _bash_history_sync
  builtin history "$@"
}

parseGitBranch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

### extract
extract() {
  if [ -f $1 ]; then
    case $1 in
    *.tar.bz2) tar xjf $1 ;;
    *.tar.gz) tar xzf $1 ;;
    *.bz2) bunzip2 $1 ;;
    *.rar) unrar e $1 ;;
    *.gz) gunzip $1 ;;
    *.tar) tar xf $1 ;;
    *.tbz2) tar xjf $1 ;;
    *.tgz) tar xzf $1 ;;
    *.zip) unzip $1 ;;
    *.Z) uncompress $1 ;;
    *.7z) 7z x $1 ;;
    *.xz) xz -dk $1 ;;
    *) echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# append to the history file, don't overwrite it
shopt -s histappend

#------------------------------------------------------------------------------
#  OS specific aliases & functions
#------------------------------------------------------------------------------

case "$OSTYPE" in linux*)

    ### determine distro
  case $(/bin/grep ^ID= /etc/os-release) in
  ID=debian )
    # apt aliases
    if [ -f /usr/bin/flatpak ]; then
      alias patch='apt update && apt upgrade && apt dist-upgrade && flatpak update -y'
    else
      alias patch='apt update && apt upgrade && apt dist-upgrade'
    fi
    alias search='apt search'
    alias install='apt install'
    alias clean='apt clean && apt autoclean && apt -y autoremove'
    alias remove='apt-get --purge remove'
    alias installed='apt list --installed'

    # source bash_completion
    if [ -f /etc/bash_completion ]; then
      . /etc/bash_completion
    fi
    ;;

  ID=archlinux )
    
    ;;
    esac

  alias ..='cd ..'
  alias ls='ls -lsh --color=auto'
  alias ll='ls -lsha --color=auto'
  alias mkdir='mkdir -pv'
  alias free='free -mt'
  alias ps='ps auxf'
  alias ip='ip -c addr'
  alias psgrep='ps aux | grep -v grep | grep -i -e VSZ -e'
  alias wget='wget -c'
  alias histg='history | grep'
  alias myip='curl ipv4.icanhazip.com'
  alias grep='grep --color=auto'
  alias df='df -h'
  alias free='free -h'
  alias reload='source ~/.bashrc'

  ### journalctl
  alias journalctl-log='journalctl -f'
  alias journalctl-boot='journalctl -b'
  alias journalctl-boot-previous='journalctl -b  -1'

  ### systemctl
  alias systemctl-depends='systemctl list-dependencies'
  alias systemctl-all='systemctl list-unit-files --type=service'
  alias systemctl-enabled='systemctl --type=service --state=active --no-pager list-units'
  alias systemctl-timers='systemctl list-timers --all'
  alias systemctl-boot-speed='systemd-analyze blame'

  ### hardware
  alias show-pci="lspci"
  alias show-hardware="lshw -short"
  alias show-hardware-full="lshw"
  alias show-hardware-network="lshw -class network"
  alias show-cpu="lscpu"
  alias show-hardware-report="hwinfo"
  alias show-usb="hwinfo"
  alias show-dmi="dmidecode"
  alias show-disk="hdparm -i /dev/sda"
  alias cputemp='sensors |grep Core'

  ;;
  esac
