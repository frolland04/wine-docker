echo ".bashrc"

echo "* Your UID is $(id -u)"
echo "* Your GID is $(id -g)"

mkdir -p ~/.local/bin

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

alias ll='ls -al'
alias
echo ""
env | grep -E "^HOME=|^PWD=|^PATH=|^HOSTNAME=|^DISPLAY=|^LD_LIBRARY_PATH="
echo ""

echo ".bashrc"

