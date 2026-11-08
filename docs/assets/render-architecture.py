"""Build the self-contained architecture SVG from locally vendored brand icons."""
from pathlib import Path
from html import escape
import re

ROOT = Path(__file__).resolve().parent
parts = ['''<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1450" viewBox="0 0 1600 1450" role="img" aria-labelledby="title desc">
<title id="title">Tencent Cloud Self-Managed Kubernetes Architecture</title>
<desc id="desc">Repository configuration: one control-plane CVM and one shared DevOps worker. Terraform provisions the foundation. Jenkins, Harbor and Argo CD support CI/CD. CFS provides dynamic storage. Monitoring is optional. Live deployment has not been verified.</desc>
<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10Z" fill="#7185a2"/></marker></defs>
<style>text{font-family:Arial,Helvetica,sans-serif;fill:#17314f}.title{font-size:36px;font-weight:700}.section{font-size:21px;font-weight:700}.name{font-size:21px;font-weight:700}.small{font-size:17px;fill:#526982}.tiny{font-size:15px;fill:#526982}.label{font-size:15px;fill:#526982;font-weight:700;letter-spacing:1.5px}</style>
<rect width="1600" height="1450" fill="#f5f8fc"/>
''']

def text(x,y,s,cls='small'):
    parts.append(f'<text x="{x}" y="{y}" class="{cls}">{escape(s)}</text>')

def rect(x,y,w,h,fill='#ffffff',stroke='#dce5ef',dash=False,r=16):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"'+(' stroke-dasharray="7 5"' if dash else '')+'/>')

def icon(name,x,y,size=36,color='#326ce5'):
    raw=(ROOT/'icons'/f'{name}.svg').read_text()
    paths=''.join(re.findall(r'<path\b[^>]*>',raw))
    parts.append(f'<g transform="translate({x},{y}) scale({size/24})" fill="{color}">{paths}</g>')

def line(points,dash=False):
    parts.append('<polyline points="'+' '.join(f'{x},{y}' for x,y in points)+'" fill="none" stroke="#7185a2" stroke-width="2" marker-end="url(#arrow)"'+(' stroke-dasharray="6 5"' if dash else '')+'/>')

def card(x,y,w,h,name,lines,brand=None,color='#326ce5',optional=False):
    rect(x,y,w,h,dash=optional)
    offset=22
    if brand:
        icon(brand,x+22,y+21,34,color)
        offset=70
    text(x+offset,y+45,name,'name')
    for i,s in enumerate(lines): text(x+22,y+78+i*25,s)

text(60,62,'Tencent Cloud | Self-Managed Kubernetes','title')
text(60,98,'Current repository configuration · Cost-saving mode · 1 control plane + 1 shared worker')
text(60,140,'PROVISIONING & DELIVERY','label')
card(60,160,440,110,'Terraform + Helm',['CVM bootstrap · platform releases'],'terraform','#844fba')
icon('helm',438,184,34,'#0f5d9b')
card(580,160,440,110,'GitHub / GitOps',['Application and infrastructure declarations'],'github','#273d57')
card(1100,160,440,110,'COS State Backend',['Encrypted Terraform remote state'])
line([(460,270),(460,292),(1320,292),(1320,270)])
text(820,311,'Terraform remote state','tiny')
rect(40,320,1520,1010,'#edf4ff','#bad0ed',r=24)
text(70,360,'TENCENT CLOUD','label')
text(330,360,'Configured region: ap-hongkong · AZ input: ap-hongkong-2')
rect(65,385,1470,750,'#f9fbff','#cfdeed',r=20)
icon('kubernetes',90,402,32)
text(136,426,'Kubernetes 1.28.8 · kubeadm · CVM private networking + security group','section')

card(90,465,330,270,'Control Plane',['k8s-master-1','4 vCPU / 8 GiB','API Server :6443 · etcd','Scheduler','Controller Manager'],'kubernetes')
line([(60,215),(25,215),(25,605),(80,605)])
text(60,299,'Provision / SSH bootstrap','tiny')
rect(455,450,1055,650,'#eef4fc','#c9daed')
text(480,479,'SHARED WORKER · k8s-node-1 · 8 vCPU / 16 GiB · purpose=devops','label')
card(480,500,1005,90,'ingress-nginx',['DaemonSet · hostNetwork · HTTP :80 · preferred DevOps affinity'],'nginx','#009639')
text(1110,545,'Public node IP / domain → HTTP','tiny')
card(480,635,310,115,'Jenkins',['Controller + build scheduling'],'jenkins','#d24939')
card(827,635,310,115,'Harbor',['Container image registry'],'harbor','#60b5d3')
card(1174,635,310,115,'Argo CD',['GitOps reconciliation'],'argo','#ef7b4d')
for x in [635,982,1329]: line([(x,590),(x,625)])
text(854,619,'Ingress → Service','tiny')
card(480,805,310,125,'Build Agents',['cicd-build namespace','Ephemeral agent Pods'],'docker','#2496ed')
card(827,805,310,125,'Applications',['dev / uat / preprod / prod','PSA enforce: restricted'],'kubernetes')
card(1174,805,310,125,'Crossplane Core',['Providers / cloud declarations','supplied by external GitOps'])
line([(635,750),(635,795)])
text(649,781,'schedule','tiny')
line([(1329,750),(1329,775),(982,775),(982,795)])
text(1062,767,'sync application manifests','tiny')
line([(1370,750),(1370,795)],True)
text(1380,781,'infra','tiny')
rect(480,970,1005,105,'#ffffff','#b9c8da',True)
icon('prometheus',502,993,34,'#e6522c')
icon('grafana',552,993,34,'#f46800')
text(610,1008,'Optional Observability','name')
text(610,1041,'Prometheus · Alertmanager · Grafana · Promtail → Loki')
text(502,1060,'create.sh: skipped by default','tiny')

card(90,800,330,225,'Cluster Foundation',['Calico VXLAN','Pod CIDR: 192.168.0.0/16','CoreDNS · kube-proxy IPVS','Docker + cri-dockerd','kubelet on each node'])
line([(420,605),(445,605)],False)
text(95,767,'Schedules and controls worker workloads','tiny')
line([(1040,1100),(1040,1160)])
text(1055,1149,'PVC-backed workloads','tiny')
rect(90,1170,1420,110,'#ffffff','#cbd9e8')
text(115,1205,'PERSISTENT STORAGE','label')
text(115,1245,'PVC / PV → StorageClass','name')
line([(465,1235),(535,1235)])
text(560,1245,'CFS CSI Driver','name')
line([(775,1235),(845,1235)])
text(870,1210,'Tencent Cloud CFS','name')
text(870,1244,'Dynamic provisioning · NFS v3 · access group + CIDR rules')

text(60,1370,'CONFIGURATION BOUNDARIES','label')
text(60,1400,'Solid arrows: main configured relationships. Dashed: optional or dependent on external declarations.','tiny')
text(60,1426,'No CLB / API VIP configured · Plane disabled · Live state unverified · Reviewed 2026-11-08','tiny')
parts.append('</svg>')
(ROOT/'architecture.svg').write_text('\n'.join(parts))
print(ROOT/'architecture.svg')
