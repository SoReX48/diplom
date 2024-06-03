# Дипломная работа - Пешкин Евгений

### Подготовка VM для работы с Yandex Cloud

Для начала инициализируем наши конфигурационные файлы terraform

![image](https://github.com/SoReX48/diplom/blob/main/images/1.png)

![image](https://github.com/SoReX48/diplom/blob/main/images/2.png)

### Поднимаем нашу инфраструктуру

После того как мы проверили terraform на работоспособность и проинициализировали наши конфигурационные файлы
Пробуем поднять нашу инфраструктуру

![image](https://github.com/SoReX48/diplom/blob/main/images/3.png)

Убеждаемся в том что были созданы target group, backend group, http-router и наш балансировщик

![image](https://github.com/SoReX48/diplom/blob/main/images/6.png)

![image](https://github.com/SoReX48/diplom/blob/main/images/7.png)

![image](https://github.com/SoReX48/diplom/blob/main/images/8.png)

![image](https://github.com/SoReX48/diplom/blob/main/images/9.png)

Проверяем VPC, Security Groups

![image](https://github.com/SoReX48/diplom/blob/main/images/20.png)

![image](https://github.com/SoReX48/diplom/blob/main/images/21.png)

После того как мы убедились в том что наши конфигурационные файлы были реализованны в полной мере можем приступать к развертыванию плейбуков на наших Виртуальных машинах

### Доступ
Доступ к нашим хостам осуществляется только по ssh через bastion. Например, для подключения к серверу Elasticsearch нам необходимо выполнить команду;
ssh -i ~/.ssh/yc_ed25519 -J user@158.160.154.197 user@192.168.3.10
![image](https://github.com/SoReX48/diplom/blob/main/images/22.png)

### Сайт
В первую очередь проверяем доступность наших web серверов nginx

![image](https://github.com/SoReX48/diplom/blob/main/images/4.png)

Запускаем ansible-playbook [nginx.yml](https://github.com/SoReX48/diplom/blob/main/ansible/nginx.yml)
C копированием веб-морды [index.html](https://github.com/SoReX48/diplom/blob/main/ansible/index.html)
и Конфига который нам потребуется для инициализации nginx-a zabbix-oм [stub_status.conf](https://github.com/SoReX48/diplom/blob/main/ansible/config/nginx/stub_status.conf)

#### Тестируем доступность сайта
'curl -v 158.160.158.215:80'

![image](https://github.com/SoReX48/diplom/blob/main/images/10.png)

Проверяем сайт через web

![image](https://github.com/SoReX48/diplom/blob/main/images/11.png)

### Мониторинг
Проверяем доступность ВМ

![image](https://github.com/SoReX48/diplom/blob/main/images/12.png)

Запускаем ansible-playbook [zabbix.yml](https://github.com/SoReX48/diplom/blob/main/ansible/zabbix.yml)

Теперь необходимо организовать сбор метрик с наших веб серверов 
Запускаем ansible-playbook [zabbix-agent.yml](https://github.com/SoReX48/diplom/blob/main/ansible/zabbix.yml) 
c копированием конфигурационного файла [zabbix_agent.conf](https://github.com/SoReX48/diplom/blob/main/ansible/config/zabbix_agent.conf)

![image](https://github.com/SoReX48/diplom/blob/main/images/13.png)
![image](https://github.com/SoReX48/diplom/blob/main/images/14.png)

Настраиваем дашборд
![image](https://github.com/SoReX48/diplom/blob/main/images/15.png)

Дашборд доступен по адресу:
http://158.160.141.27:8080/zabbix.php?action=dashboard.view

- Логин Admin
- Пароль zabbix

### Логи

#### Cтавим Elasticsearch
Запускаем ansible-playbook [elasticsearch.yml](https://github.com/SoReX48/diplom/blob/main/ansible/elasticsearch.yml)
Заходим в виртуальную машину elastic и проверяем его работоспособность
![image](https://github.com/SoReX48/diplom/blob/main/images/16.png)

#### Ставим Kibana
Запускаем ansible-playbook [kibana.yml](https://github.com/SoReX48/diplom/blob/main/ansible/kibana.yml)
![image](https://github.com/SoReX48/diplom/blob/main/images/17.png)

#### Cтавим Filebeat
Запускаем ansible-playbook [filebeat.yml](https://github.com/SoReX48/diplom/blob/main/ansible/filebeat.yml)

#### Проверяем работу стека для сбора логов
![image](https://github.com/SoReX48/diplom/blob/main/images/19.png)

Стек доступен по ссылке: http://158.160.128.91:5601/app/discover#/?_g=(filters:!(),refreshInterval:(pause:!t,value:0),time:(from:now-15m,to:now))&_a=(columns:!(),filters:!(),index:'filebeat-*',interval:auto,query:(language:kuery,query:''),sort:!(!('@timestamp',desc)))

### Проверяем работу резервного копирования
Для настройки резервного копирования используется конфигурационный файл terraform [snapshots.tf](https://github.com/SoReX48/diplom/blob/main/terraform/snapshots.tf)

![image](https://github.com/SoReX48/diplom/blob/main/images/23.jpg)
