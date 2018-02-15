#!/bin/bash
set -e

# return true if specified directory is empty
function directory_empty() {
  [ -n "$(find "${1}"/ -prune -empty)" ]
}

echo Running: "$@"

if [[ `basename ${1}` == "httpd" ]]; then

  BASE=/data/svn
  declare -A repos
  for r in ${SUBVERSION_REPOS} # No spaces allowed...
  do
    DIR=`echo ${r} | cut -s -d/ -f1`
    REP=`echo ${r} | cut -s -d/ -f2`
    if [[ -n ${DIR} && -n ${REP} && `basename ${r}` == "${REP}" ]]; then
      repos[${DIR}]+=" ${REP}"
      if [[ ! -d ${BASE}/${DIR}/${REP} ]]; then
        if [[ ! -d ${BASE}/${DIR} ]]; then
          mkdir -p ${BASE}/${DIR}
          ln -s ../.svn.access ${BASE}/${DIR}/.svn.access
          chown -R apache:apache ${BASE}/${DIR}

          current_desc=DESCRIPTION_${DIR}
          apache_snippet="<Location \"/svn/${DIR}\">\n  DAV svn\n  DavMinTimeout 300\n  SVNParentPath ${BASE}/${DIR}\n  SVNListParentPath on\n  SVNIndexXSLT /repos/.svnindex.xsl\n  AuthzSVNAccessFile ${BASE}/${DIR}/.svn.access\n</Location>\n"
          sed -i -e "s#// additional paths...#\$config->parentPath('${BASE}/${DIR}', '${!current_desc}');\n&#g" /var/www/html/include/config.php
          sed -i -e "s#^\# additional repo groups...#${apache_snippet}&#g" /etc/apache2/conf.d/svn.conf
        fi
        svnadmin create ${BASE}/${DIR}/${REP}
        chown -R apache:apache ${BASE}/${DIR}/${REP}
        echo "Repository ${BASE}/${DIR}/${REP} inside [${!current_desc}] created..."
      fi
    else
      echo "Skipping invalid: ${r}"
    fi
  done

  # for key in ${!repos[*]}; do
  #   # dynamicly making variable name
  #   current_desc=DESCRIPTION_$key
  #   for value in ${repos[$key]}; do
  #     # getting values
  #     echo "repo[$key] = $value (${!current_desc})"
  #   done
  # done

  if [[ -n $LDAP_ALIAS && -n $LDAP_URL && -n $LDAP_BindDN && -n $LDAP_BindPW ]]; then
cat <<EOT >>/etc/apache2/conf.d/ldap.conf
<AuthnProviderAlias ldap ${LDAP_ALIAS}>
  AuthLDAPURL ${LDAP_URL}
  AuthLDAPBindDN ${LDAP_BindDN}
  AuthLDAPBindPassword ${LDAP_BindPW}
  AuthLDAPBindAuthoritative off
</AuthnProviderAlias>
EOT
    sed -i -e "s/AuthBasicProvider file/AuthBasicProvider file ${LDAP_ALIAS}/g" /etc/apache2/conf.d/*.conf
  fi

  # sed 's/^Fred.*/& ***/' filename

  touch /var/log/apache2/error.log
  touch /var/log/apache2/access.log

  tail -f /var/log/apache2/error.log &
  tail -f /var/log/apache2/access.log &

  # /usr/bin/svnserve -d -r ${BASE} --listen-port 3960
  exec "$@" </dev/null 2>&1

fi

exec "$@"
