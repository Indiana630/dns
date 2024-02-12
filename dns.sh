#!/bin/bash
instalarservicio() {
echo "Instalando bind"
apt update
apt install bind9
echo "Servicio instalado correctamente"
}

menu() {
echo "Menu de resolucion DNS"
echo "1. Resolver nombreDNS"
echo "2. Resolver nombreDNS a partir de uno ya existente"
echo "3. Salir"
read menuselect
if [ $menuselect = "1" ]
then
  resolverip
elif [ $menuselect = "2" ]
then
  resolvernombre
elif [ $menuselect = "3" ]
then
  clear
  echo "El servidor dns ha sido configurado al 100%, pero se recomiendo hacer comandos de comprobacion"
else
  clear
  echo "No te entiendo, repitamos"
  menu
fi
}


aplicarcambios() {
if [ $respuesta = "y" ]
then
  if [ $menuselect = "1" ]
  then
    cat /etc/bind/db.$dominio.nuevo >> /etc/bind/db.$dominio
    cat /etc/bind/db.$inversa.nuevo >> /etc/bind/db.$inversa
    rm -f /etc/bind/db.$inversa.nuevo
    rm -f /etc/bind/db.$dominio.nuevo
    echo "Tus cambios han sido guardados, volvemos al menu"
    sleep 2
    clear
    menu
  elif [ $menuselect = "2" ]
  then
    cat /etc/bind/db.$dominio.nuevo >> /etc/bind/db.$dominio
    rm -f /etc/bind/db.$dominio.nuevo
    echo "Tus cambios han sido guardados, volvemos al menu"
    sleep 2
    clear
    menu
  fi
elif [ $respuesta = "n" ]
then
  if [ $menuselect = "1" ]
  then
    rm -f /etc/bind/db.$inversa.nuevo
    rm -f /etc/bind/db.$dominio.nuevo
    echo "Tus cambios no han sido guardados, volvemos al menu"
    sleep 2
    clear
    menu
  elif [ $menuselect = "2" ]
  then
    rm -f /etc/bind/db.$dominio.nuevo
    echo "Tus cambios no han sido guardados, volvemos al menu"
    sleep 2
    clear
    menu
  fi
else
  read -p "No me ha quedado claro, ¿puede repetir?(y/n): " respuesta
  aplicarcambios
fi
}


resolverip() {
clear
read -p "Dime el nombre de dominio a resolver: " dominioresolv
read -p "Dime la ip correspondiente: " ipdominio
read -p "Dime la ip correspondiente(la parte de hosts): " inversahost
cat > /etc/bind/db.$dominio.nuevo <<EOF
$dominioresolv  IN  A  $ipdominio
EOF
cat > /etc/bind/db.$inversa.nuevo <<EOF
$inversahost  IN  PTR  $dominioresolv
EOF
echo "La resolucion del nombreDNS ha sido correcta los parametros son:"
echo "Dominio a resover: " $dominioresolv
echo "Ip correspondiente: " $ipdominio
echo "Ip(host): " $inversahost
read -p "¿Deseas aplicar los cambios?(y/n): " respuesta
aplicarcambios
}


resolvernombre() {
clear
read -p "Dime el nombre de dominio a resolver: " dominioresolv
read -p "Dime la dominio ya existente: " dominiocor
cat > /etc/bind/db.$dominio.nuevo <<EOF
$dominioresolv  IN  CNAME  $dominiocor
EOF
echo "La resolucion del nombreDNS ha sido correcta los parametros son:"
echo "Dominio a resover: " $dominioresolv
echo "Dominio existente: " $dominiocor
read -p "¿Deseas aplicar los cambios?(y/n): " respuesta
aplicarcambios
}

staticip() {
read -p "IP Estática Ej. 192.168.100.10/24: " staticip
read -p "¿Estas seguro?(y/n)" resp
if [ $resp = "y" ]
then
echo "OK"
elif [ $resp = "n" ]
then
staticip
else
staticip
fi
}

gatewayip() {
read -p "IP router: " gatewayip
read -p "¿Estas seguro?(y/n)" resp
if [ $resp = "y" ]
then
echo "OK"
elif [ $resp = "n" ]
then
gatewayip
else
gatewayip
fi
}

nameserversip() {
read -p "Servidores DNS: " nameserversip
read -p "¿Estas seguro?(y/n)" resp
if [ $resp = "y" ]
then
echo "OK"
elif [ $resp = "n" ]
then
nameserversip
else
nameserversip
fi
}

dominio() {
read -p "Dominio: " dominio
read -p "¿Estas seguro?(y/n)" resp
if [ $resp = "y" ]
then
echo "OK"
elif [ $resp = "n" ]
then
dominio
else
dominio
fi
}

inversa() {
read -p "Direccion estatica inversa(parte de red)  Ej. 100.168.192: " inversa
read -p "¿Estas seguro?(y/n)" resp
if [ $resp = "y" ]
then
echo "OK"
elif [ $resp = "n" ]
then
inversa
else
inversa
fi
}

TTL='$TTL'

read -p "¿Quieres instalar el servicio bind? Si ya lo tienes instalado no es necesario(y/n): " respu
if [ $respu = y ]
then
clear
instalarservicio
fi
sleep 2
clear
echo "Configurando Netplan"
nic=`ifconfig | awk 'NR==1{print $1}'`
staticip
gatewayip
nameserversip
dominio
inversa
cat > /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    $nic
      dhcp4: false
      addresses:
      - $staticip
      gateway4: $gatewayip
      nameservers:
       addresses: [$nameserversip]
       search: [$dominio]
EOF
netplan apply
sleep 1
echo "Netplan operativo"
sleep 2
clear
echo "Configurando resolv.conf"
cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=$staticip
Domains=$dominio
EOF
systemctl daemon-reload
systemctl restart systemd-networkd
systemctl restart systemd-resolved
rm -f /etc/resolv.conf
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
sleep 1
echo "Resolvconf operativo"
sleep 2
clear
echo "Configurando nsswitch.conf"
cat > /etc/nsswitch.conf <<EOF
passwd:         files systemd
group:          files systemd
shadow:         files
gshadow:        files

hosts:          dns files
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
EOF
sleep 1
echo "Nsswitch operativo"
sleep 2
clear
echo "Configurando zonas"
cat > /etc/bind/named.conf.local <<EOF
zone "$dominio" {
        type master;
        file "/etc/bind/db.$dominio";
};

zone "$inversa.in-addr.arpa" {
        type master;
        file "/etc/bind/db.$inversa";
};
EOF
sleep 1
echo "Zonas operativas"
cp /etc/bind/db.local /etc/bind/db.default
cat > /etc/bind/db.default <<EOF
;
;BIND data file for local loopback interface
;
$TTL    604800
@       IN      SOA     servidor.$dominio. root.$dominio. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TLL
;
;
  IN  NS  servidor.$dominio.
EOF
cp /etc/bind/db.default /etc/bind/db.$dominio
cp /etc/bind/db.default /etc/bind/db.$inversa
rm -f /etc/bind/db.default
sleep 3
clear
echo "Vamos a configurar la resolucion de las ips"
menu
systemctl restart bind9
