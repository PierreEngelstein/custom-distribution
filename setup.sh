#!/bin/bash
sudo apt update
sudo apt upgrade -y
sudo apt remove --purge firefox-locale-fr firefox-locale-es firefox-locale-ar firefox-locale-de firefox-locale-it firefox-locale-ja firefox-locale-pt firefox-locale-ru firefox-locale-zh-hans firefox-locale-zh-hant -y
sudo apt install zsh -y
# Set zsh as default shell for everyone
sed -e "s/DSHELL=\/bin\/bash/DSHELL=\/bin\/zsh/g" /etc/adduser.conf
cat /etc/skel/.zshrc
