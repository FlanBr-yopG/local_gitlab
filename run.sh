#!/bin/bash

persistance_d_base='gitlab'
# sameersbn_docker_gitlab=master
sameersbn_docker_gitlab='10.2.4'

main() {
  local persistance_d="$(cd ../../../; pwd)/$persistance_d_base"
  set -ex
  local sed=$(sed --version 2>/dev/null | head -1 | egrep 'GNU sed' >/dev/null && echo sed || { gsed --version 1>&2 || brew install gnu-sed 1>&2 ; echo gsed ; } )
  [[ -d "$persistance_d" ]] || mkdir -p "$persistance_d"
  # chmod o+rwx "$persistance_d"
  egrep docker-compose .gitignore >/dev/null || echo 'docker-compose.yml' >> .gitignore
  [[ -e docker-compose.yml ]] || curl_wget "https://raw.githubusercontent.com/sameersbn/docker-gitlab/$sameersbn_docker_gitlab/docker-compose.yml"
  if egrep '/srv/docker/gitlab' docker-compose.yml >/dev/null ; then
    cp docker-compose.yml docker-compose.yml.bak
    cat docker-compose.yml.bak | sed -e "s+/srv/docker/gitlab+$persistance_d+g" > docker-compose.yml
    rm docker-compose.yml.bak
  fi ;
  if ! egrep 'USERMAP_UID' docker-compose.yml >/dev/null ; then
    cat docker-compose.yml     | $sed -E "s/^( *)environment: *\$/\\0\\n\\1- USERMAP_GID=$(id -g)/" > docker-compose.yml.bak
    cat docker-compose.yml.bak | $sed -E "s/^( *)environment: *\$/\\0\\n\\1- USERMAP_UID=$(id -u)/" > docker-compose.yml
    rm docker-compose.yml.bak
  fi ;
  docker-compose up -d \
  && sleep 5 \
  && echo -e "\n\nNOTE: Tailing logs. Ctrl-C to stop.\n\n" \
  && sleep 5 \
  && docker-compose logs -f
}
curl_wget() {
  local u=$1
  local f=''
  if [ ${2+x} ]; then # If $2 is defined.
    f=$2
  else
    f=$(basename "$u")
  fi;
  [[ $f ]] || f=curl_wget.file
  wget_curl_file "$u" "$f"
}
wget_curl_file() { # Args: from_URL, to_file.  Optional arg: Log.
  local log='' ;
  log=$3 ;
  [[ $log ]] || log=`mktemp "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX"` ;
  { wget -qO $2 $1 2>$log || curl -s $1 > $2 ; } &> $log ;
  local e=$?
  [[ $e -eq 0 ]] || {
    echo "ERROR: $e from wget or curl:" 1>&2
    local sets=$-
    set -x
    tail $log 1>&2
    set $sets
    echo "  (For more, see '$log'.)" 1>&2
  }
  return $e
}

cd $(dirname $0) && main "$@"

#
