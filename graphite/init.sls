{% from "graphite/settings.sls" import graphite with context %}

python-dev:
  pkg.installed

python-pip:
  pkg.installed

{% if salt['grains.get']('graphite:config:storage_schemas','None') == 'None' %}
/data/graphite/conf/storage-schemas.conf:
  file.managed:
    - source: salt://graphite/files/storage-schemas.conf
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
{% else %}
/data/graphite/conf/storage-schemas.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - contents_grains: graphite:config:storage_schemas
{% endif %}

/data/graphite/conf/carbon.conf:
  file.managed:
    - source: salt://graphite/templates/carbon.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - makedirs: True

carbon:
  pip.installed:
    - name: carbon == {{ graphite.carbon_version }}
    - install_options:
      - --prefix=/data/graphite
      - --install-lib=/data/graphite/lib
    - require:
      - pkg: python-pip
      - file: /data/graphite/conf/carbon.conf
      - file: /data/graphite/conf/storage-schemas.conf

carbon.egg-info.symlink:
    file.symlink:
        - name: /usr/lib/python2.7/dist-packages/carbon-{{ graphite.carbon_version }}-py2.7.egg-info
        - target: /data/graphite/lib/carbon-{{ graphite.carbon_version }}-py2.7.egg-info
        - force: true

whisper:
  pip.installed:
    - name: whisper == {{ graphite.carbon_version }}
    - require:
      - pkg: python-pip
      - pip: carbon

https://github.com/graphite-project/ceres/tarball/master#egg=ceres:
  pip.installed:
    - require:
      - pkg: python-pip

{% for cache in graphite.caches %}
/etc/init.d/carbon-cache-{{ loop.index }}:
  file.managed:
    - source: salt://graphite/templates/init.d
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - require:
      - pip: carbon
      - pip: whisper
    - context:
        instance_num: {{ loop.index }}
        install_path: {{ graphite.install_path }}
        type: cache

carbon-cache-{{ loop.index }}:
  service.running:
    - enable: True
    - watch:
      - file: /data/graphite/conf/carbon.conf
    - require:
      - file: /etc/init.d/carbon-cache-{{ loop.index }}
      - file: /data/graphite/conf/storage-schemas.conf
      - file: /data/graphite/conf/carbon.conf
{% endfor %}

{% for relay in graphite.relays %}
/etc/init.d/carbon-relay-{{ loop.index }}:
  file.managed:
    - source: salt://graphite/templates/init.d
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - require:
      - pip: carbon
      - pip: whisper
    - context:
        instance_num: {{ loop.index }}
        install_path: {{ graphite.install_path }}
        type: relay

carbon-relay-{{ loop.index }}:
  service.running:
    - enable: True
    - watch:
      - file: /data/graphite/conf/carbon.conf
    - require:
      - file: /etc/init.d/carbon-relay-{{ loop.index }}
      - file: /data/graphite/conf/storage-schemas.conf
      - file: /data/graphite/conf/carbon.conf
{% endfor %}
