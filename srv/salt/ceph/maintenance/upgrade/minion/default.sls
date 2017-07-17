update salt:
  salt.state:
    - tgt: '*'
    - sls: ceph.updates.salt

ready:
  salt.runner:
    - name: minions.ready
    - timeout: {{ salt['pillar.get']('ready_timeout', 300) }}

mines:
  salt.state:
    - tgt: '*'
    - sls: ceph.mines
    - failhard: True

sync:
  salt.state:
    - tgt: '*'
    - sls: ceph.sync
    - failhard: True

repo:
  salt.state:
    - tgt: '*'
    - sls: ceph.repo
    - failhard: True

common packages:
  salt.state:
    - tgt: '*'
    - sls: ceph.packages.common
    - failhard: True

{% if salt['saltutil.runner']('cephprocesses.mon') == True %}

{% for host in salt.saltutil.runner('select.minions', cluster='ceph', roles='mon') %}

upgrading mon on {{ host }}:
  salt.runner:
    - name: minions.message
    - content: "Upgrading mon on host {{ host }}"

wait until the cluster has recovered before processing mon on {{ host }}:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.wait
    - failhard: True

# OSDs are up and running althouth officially not starting because a missing flag..
check if all processes are still running after processing mon on {{ host }}:
  salt.state:
    - tgt: '*'
    - sls: ceph.processes
    - failhard: True

updating mon {{ host }}:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.upgrade
    - failhard: True

restart mon {{ host }} if updates require:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.mon.restart
    - failhard: True

upgraded mon on {{ host }}:
  salt.runner:
    - name: minions.message
    - content: "Upgraded mon on host {{ host }}"

{% endfor %}

{% for host in salt.saltutil.runner('orderednodes.unique', cluster='ceph', exclude=['mon']) %}

upgrading {{ host }}:
  salt.runner:
    - name: minions.message
    - content: "Upgrading host {{ host }}"

# wait until the OSDs/MONs are acutally marked as down ~30 seconds ~1m
wait for ceph to mark services as out/down to process {{ host }}:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.wait.until.expired.30sec

wait until the cluster has recovered before processing {{ host }}:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.wait
    - failhard: True

check if all processes are still running after processing {{ host }}:
  salt.state:
    - tgt: '*'
    - sls: ceph.processes
    - failhard: True

unset noout after processing {{ host }}:
  salt.state:
    - sls: ceph.noout.unset
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

updating {{ host }}:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.upgrade
    - failhard: True

set noout {{ host }}: 
  salt.state:
    - sls: ceph.noout.set
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

restart {{ host }} if updates require:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.updates.restart
    - failhard: True

upgraded {{ host }}:
  salt.runner:
    - name: minions.message
    - content: "Upgraded host {{ host }}"

{% endfor %}

unset noout after final iteration: 
  salt.state:
    - sls: ceph.noout.unset
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

set luminous osds: 
  salt.state:
    - sls: ceph.setosdflags
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

{% else %}

updates:
  salt.state:
    - tgt: '*'
    - sls: ceph.upgrade

restart:
  salt.state:
    - tgt: '*'
    - sls: ceph.updates.restart

{% endif %}
