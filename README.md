### Описание
Для запуска playbooks использовать контейнер, собранный в ```./ansible-docker``` \
Сборка и проверка версии Ansible:
```shell script
cd ansible-docker
docker build -t ansible-playbook . && docker run -v $(pwd):/ansible/playbooks --name ansible-playbook --rm ansible-playbook --version
```

### Запуск playbooks
Перейти в каталог с плейбуком и запустить плейбук через контейнер с ansible, указав файл инвентаря и файл с переменными (если используются):
```shell script
cd online2/
docker run --rm -it -v $(pwd):/ansible/playbooks ansible-playbook -i [path to inventory yml-file] [path to playbook yml-file] --extra-vars "@[path to vars yml-file]"
```

### Выполнение любых команд ansible-playbook:
```shell script
docker run --rm -it -v $(pwd):/ansible/playbooks ansible-playbook [comand line arguments]
```
