## Folder Script

```text
scripts/      = Lobby
scriptsgame/  = Gameplay
```

`Workspace`, map, building, dan Part tidak perlu masuk GitHub.

### GitHub Sync

```bash
git add .
git commit -m "Update scripts"
git push
```

## Update Script (MAP LOBBY) to GitHub

```bash
git add scripts
git commit -m "Update scripts"
git push
```

## Update Script (MAP GAMEPLAY) to GitHub
```bash
git add scriptsgame
git commit -m "Add gameplay scripts"
git push
```


## Lanjutan

Jika di perlukan untuk terkoneksi
```bash
git pull --rebase origin main
```
Kalau selesai tanpa CONFLICT, lanjut:
### Agar Sync
```bash
git push
```
### Untuk mengecek perubahan sebelum push, kamu bisa pakai:
```bash
git status
```
### Kalau mau lihat persis kode apa yang berubah:
```bash
git diff
```

## Perbedaan Lanjutan
`scripts`      = Lobby

`scriptsgame`  = Gameplay

``Perbedaan Script adalah bagian Lobby,
dan ScriptGame adalah bagian gameplay.
Tepatnya dalam game punya 2 place.``

# BY RYAN
[Contact Me.](https://kaptenleaky@mail.com)
