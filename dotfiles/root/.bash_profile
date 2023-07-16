# source profile
. /root/.profile
# source bashrc for interactive shells
case $- in *i*) . /root/.bashrc ;; esac
