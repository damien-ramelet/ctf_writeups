# Murder Scene - Misc

### Énoncé

Vous découvrez une scène de crime dans laquelle un parchemin illisible semble détenir des secrets.

Parviendrez-vous à résoudre cette énigme ?

---

### Résolution

On nous remet un fichier zip contenant un fichier `chiffrement.js`, un fichier `hidden.txt` contenant avec une grande suite de caractères inintelligible ainsi qu’un fichier `seek.gpg`.
L’énoncé est clair, nous devons retrouver la secret key cachée dans le fichier `hidden.txt` pour déchiffrer le fichier GPG et obtenir le flag. Commençons par analyser le fichier `chiffrement.js`.

```javascript
const cle = 'caches';
const fs = require('fs');
const secret_key = '<REDACTED>'

function chiffrement(cle) {
    let tab_nouveauCaractere = [];
    let i_range = Math.random() * 100000 - 5;
    let i_index = 0;
    const tab_caracteres = cle.split('');
    const tab_charactereascii = [];
    for (let i = 32; i < 127; i++) {
        tab_charactereascii.push(String.fromCharCode(i));
    }
    let bool_validation = false;
    while (!bool_validation) {
        for (let i = 0; i < i_range; i++) {
            let str_randomLetter = tab_charactereascii[Math.round(Math.random() * 94)];
            if (tab_caracteres.includes(str_randomLetter) && i_index != -1) {
                i_index = 0;
            }
            if (Math.random() * 100 > 95 && i_index != -1) {
                tab_nouveauCaractere.push(tab_caracteres[i_index]);
                i_index++;
            }
            if (i_index == tab_caracteres.length && i_index != -1) {
                bool_validation = true;
                tab_nouveauCaractere.push(secret_key);
                i_index = -1;
            }
            tab_nouveauCaractere.push(str_randomLetter);
        }
    }
    let str_fileString = tab_nouveauCaractere.join('');
    fs.writeFile('hidden.txt', str_fileString, (err) => {
        if (err) throw err;
        console.log('Fichier écrit avec succès');
```

Une seule fonction est définie, `chiffrement`. Elle initialise trois arrays:

- `tab_nouveauCaractere` qui sera rempli au fur et à mesure et qui in fine sera le contenu de notre fichier.
- `tab_caracteres` avec tous les caractères de la "clé de chiffrement" (différente de la secret key du fichier GPG qui est par ailleurs obfusquée)
- `tab_charactereascii` avec tous les caractères imprimables 

Le script initialise `i_range` et itère jusqu’à cette valeur. À chaque tour de boucle on choisit un caractère aléatoirement parmi tous ceux imprimables cités précédemment, et diverses actions sont faites:

- On ajoute ce caractère à notre fichier (`tab_nouveauCaractere`)
- Dans 5% des cas, on ajoute également un caractère de la "clé de chiffrement" à notre fichier
- Enfin, si `i_index` atteint la taille de la clé, on pousse la secret key dans notre fichier.

Cette dernière étape nous donne plusieurs informations:

- La secret key est quelque part en clair dans le fichier
- Elle est directement positionnée après le dernier caractère de la "clé de chiffrement" (`i_index` doit valoir `tab_caracteres.length`, et le seul endroit où `i_index` est incrémenté c’est dans le bloc qui pousse un caractère de cette dernière une fois sur 20)

On peut faire un rapide script pour extraire toutes les chaînes de caractères qui suivent directement un `s` et stocké ça dans un fichier:

```python
In [1]: with open("hidden.txt", "r") as f:
   ...:     content = f.read()
   ...: 

In [2]: possible_keys = []
   ...: for i, char in enumerate(content):
   ...:     if char == "s":
   ...:         for j in range(50):
   ...:             possible_keys.append(content[i+1:i+j] + "\n")
   ...: 

In [3]: with open("keys", "w") as f:
   ...:     f.writelines(possible_keys)
   ...:
```

Ne sachant pas de combien de caractères se compose la secret key, une taille de 50 maximum paraît être un bon compromis pour le moment

```bash
$ cat keys | wc -l
31650
```

Ça paraît raisonnable ! Il n’y a plus qu’à laisser faire gpg pour rapidement voir apparaître le flag:

```bash
$ for key in $(cat keys); do echo $key | gpg --batch --passphrase-fd 0 -d seek.gpg && break; done; 
...
...
gpg: données chiffrées avec AES256.CFB
gpg: chiffré avec 1 phrase secrète
gpg: échec du déchiffrement : Bad session key
gpg: données chiffrées avec AES256.CFB
gpg: chiffré avec 1 phrase secrète
SHLK{w311_d0n3_f0rc3r}
```

Flag !
