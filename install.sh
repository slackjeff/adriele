#!/usr/bin/env bash
#=================HEADER=====================================================|
#AUTHOR
# Jefferson Rocha <root@slackjeff.com.br>, Blemmi Secure
#
#PROGRAM
# Adriele Instalador
#
#LICENSE
# MIT
#
#============================================================================|

#=============================LIBS
if [ -e "etc/adriele.conf" ]; then # Chamando conf externa
    . etc/adriele.conf
fi

#=============================TEST's
# É root?
[ "$UID" -ne '0' ] && { echo -e "${red}Need Root.${end}"; exit 1;}


#=============================FUNCTIONS
_MENU() # Menu principal
{
 echo -e "
 [ ${cyan_}1${end_} ] - Slackware
 [ ${cyan_}2${end_} ] - Debian/Linux-Mint/Ubuntu
 [ ${cyan_}3${end_} ] - Fedora
 [ ${cyan_}4${end_} ] - Arch Linux
"
 read -p $'\e[34;1mSelecione o ID da sua Distribuição:\e[m ' select_distro
 # É nulo? É somente númerico?
 if [ -z "$select_distro" ]; then 
     echo -e "${red_}Você deve fornecer o ID da sua distribuição.${end_}"
     exit 1
 elif ! echo "$select_distro" | grep -q '^[0-9]\{1,2\}$' ; then # Somente números? 2 casas.
     echo -e "${red_}OPS. Somente Números.${end_}";
     exit 1
 fi

 # Verificando Qual Distribuição foi selecionada.
 case $select_distro in
     1)  DISTRO='slackware';;
     *)  _DIE "${red_}Nenhuma ID associada.${end_}"
 esac
}

_DIE() # Função para matar em caso de erro.
{
   echo -e "\n$1"
   exit 1
}


clear
_LOGO # Chamada do logo
_MENU # Chamada Menu

echo -e "
+++++++++++++++++++++++++++++
  Instalação do ${PRG}...
  Em Distribuição $DISTRO
+++++++++++++++++++++++++++++
"

#===========> SYSTEMS
_SLACKWARE()
{
    local rclocal="/etc/rc.d/rc.local"
    # Verificando se rc.local existe e tem permissão.
    if [ ! -e "${rclocal}" ]; then
        _DIE "${red_}ERRO 130${end_} $rclocal não existe."
    elif [ ! -x "${rclocal}" ]; then
        _DIE "${red_}ERRO${end_} $rclocal não tem permissão de execução!"
    fi

    # Copiando Executavel
    cp "${PRG}" "/etc/rc.d/rc.${PRG}" || _DIE "${red_}Impossível copiar ${PRG} para /etc/rc.d/ ${end_}"

    # Enviando informação do executável para rc.local
    if ! grep -qo "${PRG}" "$rclocal"; then # Se existe não faça.
        cat >> "${rclocal}" <<EOF
# Calling ${PRG}
if [ -x "/etc/rc.d/rc.${PRG}" ]; then
    /etc/rc.d/rc.${PRG}
fi
EOF
    fi
    return 0
}


#=============================START
# Pegando entrada de UUID's
read -p $'\e[34;1mInforme o UUID do Pendrive:\e[m '        pendrive_uuid
read -p $'\e[34;1mInforme o UUID da Raiz do Sistema:\e[m ' pc_uuid

if [ -z "$pendrive_uuid" ]; then 
    _DIE "${red_}**Você deve informa o UUID do Pendrive.${end_}"
elif [ -z "$pc_uuid" ]; then
    _DIE "${red_}**Você deve informa o UUID da raiz ' / ' do seu sistema.${end_}"
fi

# Verificando Label's dos dispositivo.
count='0' # Contadora
for label in "$pendrive_uuid" "$pc_uuid"; do
   verify_device[$count]=$(blkid -U "$label")
   [ -z "$verify_device" ] && _DIE "${red_}ERRO 122${end_} Não identifiquei o UUID. '${label}'"
   echo -e "
  ------------------------------------------------------------------------
  UUID ${label}\n  Identificado como: ${verify_device[$count]}
  ------------------------------------------------------------------------"
  count=$(( $count + 1 )) # Incremento
done
read -p $'\n\e[34;1mConfirma dispositivos? [N/y]\e[m ' confirm
confirm=${confirm,,}   # Tudo em minusculo
confirm=${confirm:=n}  # Se enter pressionado ou nulo retorna n
[ "$confirm" = "n" ] && exit 0 # N? sai.

###################################
# Preparação para gerar as Hashes
###################################

# Se caso Pendrive estiver montado
# desmonte para montar em um lugar especifico.
umount "${verify_device[0]}" &>/dev/null # Pendrive

directory_mount_tmp=$(mktemp -d) # Criando diretorio temporário

#Montando pendrive em diretório temporário.
mount "${verify_device[0]}" "$directory_mount_tmp" || _DIE "Erro ao montar ${verify_device}"

# Criando Diretório no home do Root.
readonly home_root="/root/.${PRG}"
if [ ! -d "${home_root}" ]; then
    mkdir "$home_root" || _DIE "Erro ao criar diretório em ${home_root}"
fi

# Criando diretório dentro do Pendrive
readonly directory_mount_tmp_prg="${directory_mount_tmp}/.${PRG}"
if [ ! -d "${directory_mount_tmp_prg}" ]; then
    mkdir "${directory_mount_tmp_prg}" || _DIE "Erro ao criar diretório em ${directory_mount_tmp_prg}"
fi

####################################
# Gerando as Hashes Pendrive/PC
###################################

# Gerando Hash único para o 'Pendrive'
# no home do root.
HASH_PENDRIVE=$(
    sha512sum <<<"$pendrive_uuid" | cut -d ' ' -f 1 || \
    _DIE "${red_}ERRO${end_}126, Não foi possível gerar hash para Pendrive."
)
cat > "${home_root}/${KEY_PENDRIVE}" <<EOF
PENDRIVE_UUID="$pendrive_uuid"
HASH_PENDRIVE="${HASH_PENDRIVE}"
EOF

# Gerando hash para o pendrive...
# Hash único.
HASH_PC=$(
    sha512sum <<<"$pc_uuid" | cut -d ' ' -f 1 || \
    _DIE "${red_}ERRO 127${end_} Não foi possível gerar hash para PC."
)
cat > "${directory_mount_tmp_prg}/${KEY_PC}" <<EOF
PC_UUID="$pc_uuid"
HASH_PC="${HASH_PC}"
EOF

echo -e "\n${cyan_}-HASH's Geradas.${end_}"

####################################
# Permissões e outros enfeites
# antes de ir para configurações.
###################################

# Adequando permissões de arquivos
archives=(
    "${directory_mount_tmp_prg}/${KEY_PC}"
    "${home_root}/${KEY_PENDRIVE}"
)
for perm in "${archives[@]}"; do
   chmod u=rwx,g=,o= "$perm" || _DIE "Não foi possível dar permissão para arquivo ${perm}"
done
echo -e "\n${cyan_}-PERMISSÕES Ajustadas.${end_}"

# Verificação de diretórios e arquivos necessários
echo -e "\n${cyan_}-Copias de diretórios e Arquivos.${end_}"
cp -vra 'usr/' '/' || _DIE "Não foi possível copiar diretório usr/"
cp -vra 'etc/' '/' || _DIE "Não foi possível copiar diretório etc/"


####################################
# Preparando arquivos para envio 
# de acordo com a distribuição que
# foi escolhida.
###################################

# Qual distribuição usuários escolheu?
# Vamos fazer as devidas configurações.
case $DISTRO in
    slackware) _SLACKWARE ;;
esac

####################################
# Desmontando pendrive e limpando
# arquivos/diretórios.
###################################
# Desmontando Pendrive
umount "${verify_device[0]}" &>/dev/null

# Removendo diretório temporário criado.
rm -r "$directory_mount_tmp"

# Concluído
echo -e "\n${PRG} INSTALADA COM SUCESSO."
exit 0
