#!/usr/bin/env bash

brew install ansible

brew install hudochenkov/sshpass/sshpass

# подключиться ко всем хостам:
ssh ubuntu@192.168.88.150
# либо снести старые ключи из известных ключей:
ssh-keygen -R 192.168.88.150

# выполнения плейбука:
ansible-playbook -i inventory.yml playbook.yml

nano ~/.zshrc

# выполнить плейбук в текущем (home) каталоге
alias pi='ansible-playbook -i inventory.yml playbook.yml'

# функция с передачей произвольной команды для хостов:
function picmd() {
    ansible all -i inventory.yml -m shell -a "$1"
}