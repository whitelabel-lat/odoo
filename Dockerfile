# syntax=docker/dockerfile:1
# Odoo 20 de Zellia construido desde ESTE repositorio (rama main = Odoo 20.0 + estos archivos).
# Lo despliega Dokploy como aplicación «odoo-20» (Zellia · Odoo 20) con despliegue sin caída:
# el contenedor nuevo arranca, pasa su chequeo de salud y recién entonces reemplaza al viejo.
# La imagen oficial odoo:20.0 solo aporta el sistema y las librerías; el código es el de este repo.
FROM odoo:20.0

USER root
# Fuera el Odoo empaquetado en la imagen: solo corre el código de este repo.
RUN rm -rf /usr/lib/python3/dist-packages/odoo
COPY --chown=odoo:odoo . /opt/odoo

# Arranque: genera odoo.conf desde las variables de Environment de Dokploy (PASSWORD, ADMIN_PASSWD),
# actualiza los módulos propios ya instalados (los deja en /mnt/extra-addons el servicio
# «odoo-20-modulos») y abre el servidor. Si la actualización falla, el contenedor no queda sano y
# Dokploy mantiene el anterior: nunca se corre a medias.
COPY --chmod=755 <<'SH' /usr/local/bin/zellia-odoo
#!/bin/bash
set -euo pipefail
printf '[options]\naddons_path = /mnt/extra-addons,/opt/odoo/addons,/opt/odoo/odoo/addons\ndata_dir = /var/lib/odoo\ndb_host = odoo20-db-f57kzr\ndb_port = 5432\ndb_user = odoo\ndb_password = %s\nhttp_interface = 0.0.0.0\nproxy_mode = True\nadmin_passwd = %s\nlist_db = False\ndbfilter = ^odoo20$\n' "$PASSWORD" "$ADMIN_PASSWD" > /etc/odoo/odoo.conf
MODS=$(ls /mnt/extra-addons 2>/dev/null | paste -sd, -)
if [ -n "$MODS" ]; then
  python3 /opt/odoo/odoo-bin -c /etc/odoo/odoo.conf -d odoo20 -u "$MODS" --stop-after-init --no-http
fi
exec python3 /opt/odoo/odoo-bin -c /etc/odoo/odoo.conf
SH

USER odoo
WORKDIR /opt/odoo
EXPOSE 8069
ENTRYPOINT ["/usr/local/bin/zellia-odoo"]
