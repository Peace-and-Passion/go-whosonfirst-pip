#!/usr/bin/env bash

get_data() {
  cd ${METADIR}
  echo -e "\t...pulling metadata..."
  wget --quiet -O ${f}.csv ${SOURCEURL}/bundles/${f}.csv

  cd ${DATADIR}
  echo -e "\t...pulling data..."
  wget --quiet -O ${f}.tar.bz2 ${SOURCEURL}/bundles/${f}-bundle.tar.bz2

  echo -e "\t...extracting data..."
  bunzip2 -f ${f}.tar.bz2 && tar xf ${f}.tar --strip-components=2
}

for f in ${METAFILES}; do
  # construct the metafile args
  csv="${METADIR}/${f}.csv ${csv}"

  # download data
  echo "Now working on ${f}:"

  if [[ ${UPDATEDATA} -eq "false" ]]; then
    if [ -f "${DATADIR}/${f}.tar" ]; then
      echo -e "\t...data exists, skipping..."
    else
      get_data
    fi
  else
    get_data
  fi
done

cd ${INSTALLDIR}
./bin/wof-pip-server \
  -strict \
  -loglevel info \
  -host ${HOST} \
  -port ${PORT} \
  -cache_all \
  -data ${DATADIR} ${csv}
