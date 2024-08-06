#!/bin/bash

# Função para mostrar a mensagem de uso
show_usage() {
    echo -e     "Uso: \n\n      curl -sSL https://update.ticke.tz | sudo bash\n\n"
    echo -e "Exemplo: \n\n      curl -sSL https://update.ticke.tz | sudo bash\n\n"
}

# Função para sair com erro
show_error() {
    echo $1
    echo -e "\n\nAlterações precisam ser verificadas manualmente, procure suporte se necessário\n\n"
    exit 1
}

# Função para mensagem em vermelho
echored() {
   echo -ne "\033[41m\033[37m\033[1m"
   echo -n "$1"
   echo -e "\033[0m"
}

if ! [ -n "$BASH_VERSION" ]; then
   echo "Este script deve ser executado como utilizando o bash\n\n" 
   show_usage
   exit 1
fi

# Verifica se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script deve ser executado como root" 
   exit 1
fi

CURBASE=$(basename ${PWD})
BACKEND_VOL=$(docker volume list -q | grep -e "^${CURBASE}_backend_public$")
POSTGRES_VOL=$(docker volume list -q | grep -e "^${CURBASE}_postgres_data")

if [ -f docker-compose-acme.yaml ] && [ -f .env-backend-acme ] && [ -n "${BACKEND_VOL}" ] && [ -n "${POSTGRES_VOL}" ]; then
   echored "                                               "
   echored "  Este processo irá converter uma instalação   "
   echored "  manual a partir do fonte por uma instalação  "
   echored "  a partir de imagens pré compiladas do        "
   echored "  projeto ticketz                              "
   echored "                                               "
   echored "  Aguarde 20 segundos.                         "
   echored "                                               "
   echored "  Aperte CTRL-C para cancelar                  "
   echored "                                               "
   sleep 20
   echo "Prosseguindo..."

   docker compose -f docker-compose-acme.yaml down

   docker volume create --name wecloud-docker-acme_backend_public || exit 1
   docker run --rm -v ${BACKEND_VOL}:/from -v wecloud-docker-acme_backend_public:/to alpine ash -c "cd /from ; cp -a . /to"

   docker volume create --name wecloud-docker-acme_postgres_data || exit 1
   docker run --rm -v ${POSTGRES_VOL}:/from -v wecloud-docker-acme_postgres_data:/to alpine ash -c "cd /from ; cp -a . /to"
   
   . .env-backend-acme
   
   if [ -z "${SUDO_USER}" ] ; then
     cd
   elif [ "${SUDO_USER}" = "root" ] ; then
     cd /root || exit 1
   else
     cd /home/${SUDO_USER} || exit 1
   fi
   curl -sSL get.ticke.tz | bash -s ${FRONTEND_HOST} ${EMAIL_ADDRESS}

   echo "Após os testes você pode remover os volumes antigos com o comando:"
   echo -e "\n\n    sudo docker volume rm ${BACKEND_VOL} ${POSTGRES_VOL}\n"
   
   exit 0
fi

[ -f credentials.env ] && . credentials.env

[ -n "${DOCKER_REGISTRY}" ] && [ -n "${DOCKER_USER}" ] && [ -n "${DOCKER_PASSWORD}" ] && \
echo ${DOCKER_PASSWORD} | docker login ${DOCKER_REGISTRY} --username ${DOCKER_USER} --password-stdin

if [ -d wecloud-docker-acme ] && [ -f wecloud-docker-acme/docker-compose.yaml ] ; then
  cd wecloud-docker-acme
elif [ -f docker-compose.yaml ] ; then
  ## nothing to do, already here
  echo -n "" > /dev/null
elif [ "${SUDO_USER}" = "root" ] ; then
  cd /root/wecloud-docker-acme || exit 1
else
  cd /home/${SUDO_USER}/wecloud-docker-acme || exit 1
fi

echo "Working on $PWD/wecloud-docker-acme folder"

if ! [ -f docker-compose.yaml ] ; then
  echo "docker-compose.yaml não encontrado" > /dev/stderr
  exit 1
fi

echo "Baixando novas imagens"
docker compose pull || show_error "Erro ao baixar novas imagens"

echo "Finalizando containers"
docker compose down || show_error "Erro ao finalizar containers"

echo "Inicializando containers"
docker compose up -d || show_error "Erro ao iniciar containers"

echo -e "\nSeu sistema já deve estar funcionando"

echo "Removendo imagens anteriores..."
docker system prune -af &> /dev/null

echo "Concluído"
