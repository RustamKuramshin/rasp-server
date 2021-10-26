### Ansible
Источник образа: https://github.com/walokra/docker-ansible-playbook \
Сборка и тест версии: 
```shell script
docker build -t ansible-playbook . && docker run --name ansible-playbook --rm -v $(pwd):/ansible/playbooks ansible-playbook --version
```
Запуск тестового playbook (создаст в текущем каталоге папку hello_world, которую потом можно удалить через rm):
```shell script
docker run --rm -it -v $(pwd):/ansible/playbooks ansible-playbook ansible_test.yml -i 'local,' --connection=local
sudo rm -rf hello_world/
```
